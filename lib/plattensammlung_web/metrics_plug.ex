defmodule PlattensammlungWeb.MetricsPlug do
  @moduledoc """
  Serves `GET /metrics` for Prometheus on an own port (`METRICS_PORT`, ADR 0019),
  separate from the app's endpoint: it is only reachable inside the LAN and
  never goes through nginx-proxy-manager.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(%{method: "GET", path_info: ["metrics"]} = conn, _opts) do
    conn
    |> put_resp_content_type("text/plain; version=0.0.4")
    |> send_resp(200, Plattensammlung.Metrics.prometheus())
  end

  def call(conn, _opts), do: send_resp(conn, 404, "Not found")

  @doc "Bandit child for the metrics port, or none without `:metrics_port`."
  def child_specs do
    case Application.get_env(:plattensammlung, :metrics_port) do
      nil -> []
      port -> [{Bandit, plug: __MODULE__, port: port, ip: {0, 0, 0, 0}, startup_log: false}]
    end
  end
end
