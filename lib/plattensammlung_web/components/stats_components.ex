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
  use Gettext, backend: PlattensammlungWeb.Gettext

  alias Phoenix.LiveView.JS

  @doc "A key figure with a label and an optional note; with `navigate` it is a link."
  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :note, :string, default: nil
  attr :navigate, :string, default: nil

  def stat_tile(assigns) do
    ~H"""
    <.link
      :if={@navigate}
      id={@id}
      navigate={@navigate}
      class="block rounded-lg border border-base-300 p-4 transition hover:border-primary hover:bg-base-200"
    >
      <.tile_content label={@label} value={@value} note={@note} />
    </.link>
    <div :if={!@navigate} id={@id} class="rounded-lg border border-base-300 p-4">
      <.tile_content label={@label} value={@value} note={@note} />
    </div>
    """
  end

  defp tile_content(assigns) do
    ~H"""
    <p class="text-sm opacity-70">{@label}</p>
    <p class="mt-1 text-3xl font-semibold tabular-nums">{@value}</p>
    <p :if={@note} class="mt-1 text-xs opacity-60">{@note}</p>
    """
  end

  @doc """
  Horizontal bar chart for a list of `%{label: String.t(), count: integer}`.
  `unit` says what is counted, for the hover text: `:album` or `:copy`.
  With `href` (a function entry -> path or nil) each row links to its albums.
  """
  attr :id, :string, required: true
  attr :title, :string, required: true
  attr :entries, :list, required: true
  attr :unit, :atom, default: :album, values: [:album, :copy]
  attr :href, :any, default: nil

  def bar_chart(assigns) do
    assigns =
      assign(assigns, :max, assigns.entries |> Enum.map(& &1.count) |> Enum.max(fn -> 0 end))

    ~H"""
    <section id={@id} class="space-y-3">
      <h2 class="font-semibold">{@title}</h2>
      <p :if={@entries == []} class="text-sm opacity-60">{gettext("No data yet.")}</p>
      <table :if={@entries != []} class="w-full text-sm">
        <thead class="sr-only">
          <tr>
            <th scope="col">{gettext("Category")}</th>
            <th scope="col">{gettext("Share")}</th>
            <th scope="col">{gettext("Count")}</th>
          </tr>
        </thead>
        <tbody>
          <tr
            :for={entry <- @entries}
            class={["group", row_path(@href, entry) && "cursor-pointer"]}
            title={"#{entry.label}: #{unit(@unit, entry.count)}"}
            phx-click={row_path(@href, entry) && JS.navigate(row_path(@href, entry))}
          >
            <th scope="row" class="w-2/5 max-w-0 truncate py-1 pr-3 text-left font-normal">
              <%!-- The whole row is clickable; the link is there for keyboard and screen readers --%>
              <.link
                :if={row_path(@href, entry)}
                navigate={row_path(@href, entry)}
                class="group-hover:underline"
              >
                {entry.label}
              </.link>
              <span :if={!row_path(@href, entry)}>{entry.label}</span>
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

  defp row_path(nil, _entry), do: nil
  defp row_path(href, entry), do: href.(entry)

  defp unit(:album, count), do: ngettext("1 album", "%{count} albums", count)
  defp unit(:copy, count), do: ngettext("1 copy", "%{count} copies", count)
end
