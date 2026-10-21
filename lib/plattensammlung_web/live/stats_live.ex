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
    <Layouts.app flash={@flash} current_user={@current_user}>
      <h1 class="text-2xl font-bold">Statistik</h1>

      <div id="kpis" class="grid grid-cols-2 gap-3 md:grid-cols-4">
        <.stat_tile
          id="kpi-albums"
          label="Alben"
          value={to_string(@stats.albums)}
          note={"von #{@stats.artists} Künstlern"}
        />
        <.stat_tile id="kpi-copies" label="Exemplare" value={to_string(@stats.copies)} />
        <.stat_tile id="kpi-wishlist" label="Wunschliste" value={to_string(@stats.wishlist)} />
        <.stat_tile
          id="kpi-value"
          label="Kaufwert"
          value={format_euro(@stats.value)}
          note={value_note(@stats)}
        />
      </div>

      <div class="grid gap-x-12 gap-y-10 md:grid-cols-2">
        <.bar_chart id="chart-genres" title="Genres" entries={@stats.genres} />
        <.bar_chart id="chart-decades" title="Jahrzehnte" entries={@stats.decades} />
        <.bar_chart id="chart-artists" title="Meiste Alben" entries={@stats.top_artists} />
        <.bar_chart
          id="chart-conditions"
          title="Zustand der Platten"
          entries={@stats.conditions}
          unit={{"Exemplar", "Exemplare"}}
        />
      </div>

      <section id="export" class="space-y-3 rounded-lg border border-base-300 p-4">
        <div>
          <h2 class="font-semibold">Export</h2>
          <p class="text-sm opacity-70">
            CSV mit allen Feldern (Sammlung und Wunschliste) als Backup oder für die Tabellenkalkulation.
            JSON-LD (schema.org) beschreibt die Sammlung ohne private Angaben wie Preise und Lagerort.
          </p>
        </div>
        <div class="flex flex-wrap gap-2">
          <.link href={~p"/export/plattensammlung.csv"} class="btn btn-sm" id="export-csv" download>
            <.icon name="hero-table-cells" class="size-4" /> CSV herunterladen
          </.link>
          <.link
            href={~p"/export/plattensammlung.jsonld"}
            class="btn btn-sm"
            id="export-jsonld"
            download
          >
            <.icon name="hero-code-bracket" class="size-4" /> JSON-LD herunterladen
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
     |> assign(:page_title, "Statistik")
     |> assign(:stats, Records.statistics!(actor: socket.assigns.current_user))}
  end

  defp value_note(%{priced_copies: 0}), do: "noch keine Kaufpreise erfasst"
  defp value_note(%{priced_copies: 1}), do: "aus 1 Exemplar mit Preis"
  defp value_note(%{priced_copies: n}), do: "aus #{n} Exemplaren mit Preis"

  defp format_euro(decimal) do
    [euros, cents] =
      decimal |> Decimal.round(2) |> Decimal.to_string(:normal) |> String.split(".")

    thousands =
      euros
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(".", &Enum.join/1)
      |> String.reverse()

    "#{thousands},#{cents} €"
  end
end
