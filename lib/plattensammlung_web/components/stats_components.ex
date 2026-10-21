defmodule PlattensammlungWeb.StatsComponents do
  @moduledoc """
  Stat tiles and horizontal bar charts for the statistics page.

  Bars are a single series in one hue (the theme's primary color), so there is
  no legend. Every bar carries its label and value as text in the normal ink
  color: the primary color has less than 3:1 contrast to the page in both
  themes, so the numbers must never depend on the bar alone. The chart is a
  real <table>, which doubles as the accessible table view.
  """
  use Phoenix.Component

  @doc "A key figure with a label and an optional note."
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :note, :string, default: nil

  def stat_tile(assigns) do
    ~H"""
    <div id={@id} class="rounded-lg border border-base-300 p-4">
      <p class="text-sm opacity-70">{@label}</p>
      <p class="mt-1 text-3xl font-semibold tabular-nums">{@value}</p>
      <p :if={@note} class="mt-1 text-xs opacity-60">{@note}</p>
    </div>
    """
  end

  @doc """
  Horizontal bar chart for a list of `%{label: String.t(), count: integer}`.
  `unit` names one counted thing for the hover text, e.g. {"Album", "Alben"}.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :entries, :list, required: true
  attr :unit, :any, default: {"Album", "Alben"}

  def bar_chart(assigns) do
    assigns =
      assign(assigns, :max, assigns.entries |> Enum.map(& &1.count) |> Enum.max(fn -> 0 end))

    ~H"""
    <section id={@id} class="space-y-3">
      <h2 class="font-semibold">{@title}</h2>
      <p :if={@entries == []} class="text-sm opacity-60">Noch keine Daten.</p>
      <table :if={@entries != []} class="w-full text-sm">
        <thead class="sr-only">
          <tr>
            <th scope="col">Kategorie</th>
            <th scope="col">Anteil</th>
            <th scope="col">Anzahl</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={entry <- @entries}
            class="group"
            title={"#{entry.label}: #{entry.count} #{unit(@unit, entry.count)}"}
          >
            <th scope="row" class="w-2/5 max-w-0 truncate py-1 pr-3 text-left font-normal">
              {entry.label}
            </th>
            <td class="py-1">
              <%!-- 12px bar from a square baseline, 4px rounded data end --%>
              <div
                class="h-3 rounded-r bg-primary transition-opacity group-hover:opacity-80"
                style={"width: #{bar_width(entry.count, @max)}%"}
              >
              </div>
            </td>
            <td class="w-10 py-1 pl-3 text-right tabular-nums">{entry.count}</td>
          </tr>
        </tbody>
      </table>
    </section>
    """
  end

  # At least a sliver, so a count of 1 next to a large maximum stays visible
  defp bar_width(_count, 0), do: 0
  defp bar_width(count, max), do: max(count / max * 100, 2) |> Float.round(1)

  defp unit({one, _many}, 1), do: one
  defp unit({_one, many}, _count), do: many
end
