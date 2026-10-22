defmodule PlattensammlungWeb.StatsLive do
  @moduledoc """
  Statistics of the collection (generic action `Album.statistics`) and the
  export downloads.
  """
  use PlattensammlungWeb, :live_view

  import PlattensammlungWeb.StatsComponents

  alias Plattensammlung.Records

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_path={@current_path}>
      <h1 class="text-2xl font-bold">{gettext("Statistics")}</h1>

      <div id="kpis" class="grid grid-cols-2 gap-3 md:grid-cols-4">
        <.stat_tile
          id="kpi-albums"
          label={gettext("Albums")}
          value={to_string(@stats.albums)}
          navigate={~p"/"}
        />
        <.stat_tile
          id="kpi-copies"
          label={gettext("Copies")}
          value={to_string(@stats.copies)}
          navigate={~p"/"}
        />
        <.stat_tile
          id="kpi-wishlist"
          label={gettext("Wishlist")}
          value={to_string(@stats.wishlist)}
          navigate={~p"/wishlist"}
        />
        <.stat_tile
          id="kpi-artists"
          label={gettext("Artists")}
          value={to_string(@stats.artists)}
        />
      </div>

      <div class="grid gap-x-12 gap-y-10 md:grid-cols-2">
        <.bar_chart
          id="chart-genres"
          title={gettext("Genres")}
          entries={translate(@stats.genres)}
          href={&albums_path/1}
        />
        <.bar_chart
          id="chart-decades"
          title={gettext("Decades")}
          entries={translate(@stats.decades)}
          href={&albums_path/1}
        />
        <.bar_chart
          id="chart-artists"
          title={gettext("Most albums")}
          entries={@stats.top_artists}
          href={&albums_path/1}
        />
        <.bar_chart
          id="chart-conditions"
          title={gettext("Condition of the records")}
          entries={translate(@stats.conditions)}
          unit={:copy}
          href={&albums_path/1}
        />
      </div>

      <section id="export" class="space-y-3 rounded-lg border border-base-300 p-4">
        <div>
          <h2 class="font-semibold">{gettext("Export")}</h2>
          <p class="text-sm opacity-70">
            {gettext(
              "CSV with all fields (collection and wishlist) as a backup or for spreadsheets. JSON-LD (schema.org) describes the collection without private details such as purchase date and notes."
            )}
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <.link href={~p"/export/plattensammlung.csv"} class="btn btn-sm" id="export-csv" download>
            <.icon name="hero-table-cells" class="size-4" /> {gettext("Download CSV")}
          </.link>
          <.link
            href={~p"/export/plattensammlung.jsonld"}
            class="btn btn-sm"
            id="export-jsonld"
            download
          >
            <.icon name="hero-code-bracket" class="size-4" /> {gettext("Download JSON-LD")}
          </.link>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, gettext("Statistics"))
     |> assign(:stats, Records.statistics!(actor: socket.assigns.current_user))}
  end

  # The statistics labels are English (they are also the API's); translate the
  # generic ones by their filter. Genres, artists and grades stay as they are.
  defp translate(entries), do: Enum.map(entries, &%{&1 | label: label(&1)})

  defp label(%{filter: nil}), do: gettext("Other")
  defp label(%{filter: %{"decade" => "unknown"}}), do: gettext("Unknown")
  defp label(%{filter: %{"decade" => decade}}), do: gettext("%{decade}s", decade: decade)
  defp label(%{filter: %{"condition" => "none"}}), do: gettext("Not graded")
  defp label(entry), do: entry.label

  # The statistics describe the collection, so the drill-down lists owned albums
  defp albums_path(%{filter: nil}), do: nil
  defp albums_path(%{filter: filter}), do: ~p"/?#{filter}"
end
