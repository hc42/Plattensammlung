defmodule Plattensammlung.Metrics do
  @moduledoc """
  Application metrics for Prometheus (ADR 0019). `Peep` collects them from
  `:telemetry` events; `PlattensammlungWeb.MetricsPlug` serves them as
  `/metrics` on an own port (`:metrics_port`, `METRICS_PORT`).

  Most events come from Phoenix, LiveView, Ash, Ecto and Finch (Req's HTTP
  client). The app adds its own:

  * `[:plattensammlung, :auth, :sign_in]` – `method` (passkey, magic_link,
    api_key) and `result` (success, failure), see `sign_in/2`
  * `[:plattensammlung, :auth, :magic_link_request]` – `result` (accepted,
    rate_limited)
  * `[:plattensammlung, :lookup, :throttle]` – time waited for MusicBrainz
  * `[:plattensammlung, :data]` – counts and sizes, measured every minute
    (`measure_data/0`)

  Per IP address nothing is counted: every address would be a new time series.
  """
  import Telemetry.Metrics

  require Logger

  @name :plattensammlung_metrics

  @doc "Children for the application: the Peep reporter and the data poller."
  def child_specs do
    [{Peep, name: @name, metrics: metrics()}] ++ data_poller()
  end

  # Off in tests: they measure explicitly inside their database sandbox
  defp data_poller do
    if Application.get_env(:plattensammlung, :measure_data?, true) do
      [
        {:telemetry_poller,
         name: :plattensammlung_data_poller,
         measurements: [{__MODULE__, :measure_data, []}],
         period: :timer.seconds(60),
         init_delay: :timer.seconds(5)}
      ]
    else
      []
    end
  end

  @doc "All metrics in the Prometheus text format."
  def prometheus, do: @name |> Peep.get_all_metrics() |> Peep.Prometheus.export()

  @doc "Reports a sign-in attempt."
  def sign_in(method, result) when result in [:success, :failure] do
    :telemetry.execute([:plattensammlung, :auth, :sign_in], %{count: 1}, %{
      method: method,
      result: result
    })
  end

  @doc "Reports a magic link request (`:accepted` or `:rate_limited`)."
  def magic_link_request(result) do
    :telemetry.execute([:plattensammlung, :auth, :magic_link_request], %{count: 1}, %{
      result: result
    })
  end

  @doc false
  # Periodic measurement (telemetry_poller). A system task without a user, so
  # it counts with `authorize?: false`.
  def measure_data do
    {cover_files, cover_bytes} = cover_stats()

    :telemetry.execute(
      [:plattensammlung, :data],
      %{
        albums: count(Plattensammlung.Records.Album),
        copies: count(Plattensammlung.Records.Copy),
        wishes: count(Plattensammlung.Records.Wish),
        artists: count(Plattensammlung.Records.Artist),
        users: count(Plattensammlung.Accounts.User),
        cover_files: cover_files,
        cover_bytes: cover_bytes,
        database_bytes: database_bytes()
      },
      %{}
    )
  rescue
    # E.g. the database is briefly unavailable: try again next minute
    error -> Logger.warning("Measuring data failed: #{Exception.message(error)}")
  end

  def metrics do
    http_metrics() ++
      live_view_metrics() ++
      ash_metrics() ++
      auth_metrics() ++
      data_metrics() ++
      external_metrics() ++
      system_metrics()
  end

  defp http_metrics do
    dispatch = [:phoenix, :router_dispatch, :stop]

    [
      counter("plattensammlung.http.requests.count",
        event_name: dispatch,
        description: "HTTP requests by route pattern, method, status and kind of client",
        tags: [:route, :method, :status, :client],
        tag_values: &http_tags/1
      ),
      distribution("plattensammlung.http.request.duration.milliseconds",
        event_name: dispatch,
        measurement: :duration,
        unit: {:native, :millisecond},
        description: "Duration of HTTP requests",
        tags: [:route, :method],
        tag_values: &http_tags/1
      ),
      counter("plattensammlung.user.requests.count",
        event_name: dispatch,
        description: "HTTP requests per signed-in user",
        tags: [:user],
        tag_values: &%{user: user_id(&1.conn.assigns)},
        keep: &signed_in?(&1.conn.assigns)
      )
    ]
  end

  defp live_view_metrics do
    [
      counter("plattensammlung.live_view.mounts.count",
        event_name: [:phoenix, :live_view, :mount, :stop],
        description: "LiveView mounts (page views) by view",
        tags: [:view],
        tag_values: &%{view: view(&1)}
      ),
      counter("plattensammlung.live_view.events.count",
        event_name: [:phoenix, :live_view, :handle_event, :stop],
        description: "LiveView events by view and event",
        tags: [:view, :event],
        tag_values: &%{view: view(&1), event: &1.event}
      ),
      distribution("plattensammlung.live_view.event.duration.milliseconds",
        event_name: [:phoenix, :live_view, :handle_event, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        description: "Duration of LiveView events",
        tags: [:view, :event],
        tag_values: &%{view: view(&1), event: &1.event}
      ),
      counter("plattensammlung.user.live_events.count",
        event_name: [:phoenix, :live_view, :handle_event, :stop],
        description: "LiveView events per signed-in user",
        tags: [:user],
        tag_values: &%{user: user_id(&1.socket.assigns)},
        keep: &signed_in?(&1.socket.assigns)
      )
    ]
  end

  # Ash actions are the same for web UI and API: one counter and one duration
  # per kind of action and domain
  defp ash_metrics do
    for domain <- [:records, :accounts],
        type <- [:create, :read, :update, :destroy, :action],
        metric <- [:count, :duration] do
      event = [:ash, domain, type, :stop]

      case metric do
        :count ->
          counter("plattensammlung.ash.actions.count",
            event_name: event,
            description: "Ash actions by resource and action",
            tags: [:domain, :resource, :action],
            tag_values: &ash_tags(&1, domain)
          )

        :duration ->
          distribution("plattensammlung.ash.action.duration.milliseconds",
            event_name: event,
            measurement: :duration,
            unit: {:native, :millisecond},
            description: "Duration of Ash actions",
            tags: [:domain, :resource, :action],
            tag_values: &ash_tags(&1, domain)
          )
      end
    end
  end

  defp auth_metrics do
    [
      counter("plattensammlung.auth.sign_ins.count",
        event_name: [:plattensammlung, :auth, :sign_in],
        description: "Sign-in attempts by method and result",
        tags: [:method, :result]
      ),
      counter("plattensammlung.auth.magic_link_requests.count",
        event_name: [:plattensammlung, :auth, :magic_link_request],
        description: "Magic link requests, accepted or over the rate limit",
        tags: [:result]
      )
    ]
  end

  defp data_metrics do
    [
      {:albums, "Albums in the shared catalog"},
      {:copies, "Copies of all users"},
      {:wishes, "Wishlist entries of all users"},
      {:artists, "Artists"},
      {:users, "Users"},
      {:cover_files, "Stored cover files"},
      {:cover_bytes, "Size of all cover files in bytes"},
      {:database_bytes, "Size of the database in bytes"}
    ]
    |> Enum.map(fn {measurement, description} ->
      last_value("plattensammlung.data.#{measurement}",
        event_name: [:plattensammlung, :data],
        measurement: measurement,
        description: description
      )
    end)
  end

  # Discogs, MusicBrainz, Wikidata, Cover Art Archive: Req sends through Finch
  defp external_metrics do
    [
      counter("plattensammlung.external.requests.count",
        event_name: [:finch, :request, :stop],
        description: "Requests to external services by host and status",
        tags: [:host, :status],
        tag_values: &finch_tags/1
      ),
      distribution("plattensammlung.external.request.duration.milliseconds",
        event_name: [:finch, :request, :stop],
        measurement: :duration,
        unit: {:native, :millisecond},
        description: "Duration of requests to external services",
        tags: [:host],
        tag_values: &finch_tags/1
      ),
      distribution("plattensammlung.external.throttle.wait.milliseconds",
        event_name: [:plattensammlung, :lookup, :throttle],
        measurement: :wait,
        description: "Time a request waited for its slot (MusicBrainz: 1 per second)",
        tags: [:service]
      )
    ]
  end

  defp system_metrics do
    [
      distribution("plattensammlung.repo.query.duration.milliseconds",
        event_name: [:plattensammlung, :repo, :query],
        measurement: :total_time,
        unit: {:native, :millisecond},
        description: "Duration of database queries by table",
        tags: [:source],
        tag_values: &%{source: &1[:source] || "other"}
      ),
      last_value("plattensammlung.vm.memory.bytes",
        event_name: [:vm, :memory],
        measurement: :total,
        description: "Memory used by the BEAM"
      ),
      last_value("plattensammlung.vm.run_queue.length",
        event_name: [:vm, :total_run_queue_lengths],
        measurement: :total,
        description: "Processes waiting to run"
      )
    ]
  end

  # Route pattern ("/albums/:id"), not the path: one series per page, not per album
  defp http_tags(%{conn: conn} = metadata) do
    %{
      route: metadata[:route] || "unmatched",
      method: conn.method,
      status: conn.status,
      client: client(conn)
    }
  end

  defp client(conn) do
    cond do
      match?(["Bearer " <> _], Plug.Conn.get_req_header(conn, "authorization")) -> "api_key"
      signed_in?(conn.assigns) -> "browser_session"
      true -> "anonymous"
    end
  end

  defp signed_in?(assigns), do: match?(%{current_user: %{id: _}}, assigns)

  defp user_id(%{current_user: %{id: id}}), do: id
  defp user_id(_assigns), do: "none"

  defp view(%{socket: %{view: view}}), do: inspect(view)
  defp view(_metadata), do: "unknown"

  defp ash_tags(metadata, domain) do
    %{
      domain: domain,
      resource: metadata[:resource_short_name] || "unknown",
      action: metadata[:action] || "unknown"
    }
  end

  defp finch_tags(%{request: request, result: result}) do
    status =
      case result do
        {:ok, %{status: status}} -> status
        _error -> "error"
      end

    %{host: request.host, status: status}
  end

  defp finch_tags(_metadata), do: %{host: "unknown", status: "unknown"}

  defp count(resource), do: Ash.count!(resource, authorize?: false)

  defp cover_stats do
    dir = Plattensammlung.Covers.dir()

    case File.ls(dir) do
      {:ok, names} ->
        sizes =
          for name <- names, {:ok, %{size: size}} <- [File.stat(Path.join(dir, name))], do: size

        {length(sizes), Enum.sum(sizes)}

      {:error, _reason} ->
        {0, 0}
    end
  end

  # Not application data, so a plain query instead of an Ash action
  defp database_bytes do
    %{rows: [[bytes]]} =
      Plattensammlung.Repo.query!("SELECT pg_database_size(current_database())")

    bytes
  end
end
