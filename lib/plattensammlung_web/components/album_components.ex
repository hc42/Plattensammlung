defmodule PlattensammlungWeb.AlbumComponents do
  @moduledoc """
  UI building blocks for albums and copies.
  """
  use Phoenix.Component

  import PlattensammlungWeb.CoreComponents, only: [icon: 1]

  alias Plattensammlung.Records.Condition

  @doc """
  Square album cover; falls back to a stylised record when there is no image.
  """
  attr :album, :map, required: true
  attr :class, :any, default: nil

  def cover(assigns) do
    ~H"""
    <div
      class={["relative aspect-square overflow-hidden rounded-lg bg-base-300 shadow-sm", @class]}
      role="img"
      aria-label={"Cover: #{@album.title}"}
    >
      <div class="grid size-full place-items-center">
        <div class="grid aspect-square w-3/4 place-items-center rounded-full bg-neutral shadow-inner">
          <div class="grid aspect-square w-1/3 place-items-center rounded-full bg-primary/70">
            <div class="size-1.5 rounded-full bg-base-100"></div>
          </div>
        </div>
      </div>
      <%!-- A background image instead of <img>: if the URL is broken, the record stays visible --%>
      <div
        :if={@album.cover_url}
        class="absolute inset-0 bg-cover bg-center"
        style={"background-image: url('#{css_url(@album.cover_url)}')"}
      >
      </div>
    </div>
    """
  end

  # Percent-encode characters that could break out of url('…')
  defp css_url(url), do: URI.encode(url, &(&1 not in ~c"'\"()\\ "))

  @doc """
  Shows whether an album is owned (with number of copies) or on the wishlist.
  Expects the `owned` and `copy_count` aggregates to be loaded.
  """
  attr :album, :map, required: true

  def status_badge(assigns) do
    ~H"""
    <span :if={@album.owned and @album.copy_count > 1} class="badge badge-sm badge-neutral">
      {@album.copy_count}×
    </span>
    <span :if={@album.wanted} class="badge badge-sm badge-accent gap-1">
      <.icon name="hero-heart-micro" class="size-3" /> Wunschliste
    </span>
    <span :if={!@album.owned and !@album.wanted} class="badge badge-sm badge-ghost">
      nicht zugeordnet
    </span>
    """
  end

  @doc """
  Camera and photo barcode scanner (JS hook `BarcodeScanner`). A recognized
  code is pushed to the LiveView as the `"scanned"` event with `%{"code" => …}`.
  """
  attr :id, :string, required: true

  def barcode_scanner(assigns) do
    ~H"""
    <%!-- The JS hook manages this element (camera, status), so LiveView must not patch it --%>
    <div
      id={@id}
      phx-hook="BarcodeScanner"
      phx-update="ignore"
      data-active="false"
      class="group space-y-2"
    >
      <div class="flex flex-wrap gap-2 group-data-[active=true]:hidden">
        <button type="button" data-start class="btn btn-sm btn-neutral" id="scan-camera">
          <.icon name="hero-camera" class="size-4" /> Mit Kamera scannen
        </button>
        <label class="btn btn-sm btn-ghost" id="scan-photo">
          <.icon name="hero-photo" class="size-4" /> Foto aufnehmen
          <input type="file" accept="image/*" capture="environment" class="hidden" />
        </label>
      </div>
      <div class="relative hidden overflow-hidden rounded-lg bg-black group-data-[active=true]:block">
        <video playsinline muted class="aspect-[4/3] w-full object-cover"></video>
        <div class="pointer-events-none absolute inset-x-[12%] inset-y-[30%] rounded-md border-2 border-white/80 shadow-[0_0_0_100vmax_rgba(0,0,0,0.35)]">
        </div>
        <div class="pointer-events-none absolute inset-x-[14%] top-1/2 h-0.5 animate-pulse bg-red-500">
        </div>
        <button
          type="button"
          data-stop
          class="btn btn-sm btn-circle absolute right-2 top-2"
          aria-label="Kamera schließen"
        >
          <.icon name="hero-x-mark" class="size-4" />
        </button>
      </div>
      <p data-status class="min-h-5 text-sm opacity-70" aria-live="polite"></p>
    </div>
    """
  end

  @doc """
  One lookup result (Discogs/MusicBrainz) as a list row: thumbnail, title,
  artist, year, source and pressing. The default slot adds lines below the
  details, the `actions` slot adds buttons on the right.
  """
  attr :id, :string, required: true
  attr :result, :map, required: true
  slot :inner_block
  slot :actions

  def lookup_result(assigns) do
    ~H"""
    <li id={@id} class="flex gap-4 py-4">
      <.cover album={%{cover_url: @result.thumb_url, title: @result.title}} class="size-20 shrink-0" />
      <div class="min-w-0 flex-1 space-y-1">
        <p class="truncate font-medium">{@result.title}</p>
        <p class="truncate text-sm opacity-70">{@result.artist_name}</p>
        <p class="flex flex-wrap items-center gap-1.5 text-xs opacity-60">
          <span :if={@result.year}>{@result.year}</span>
          <span class="badge badge-ghost badge-xs">{source_label(@result.source)}</span>
          <span :if={pressing_text(@result)}>{pressing_text(@result)}</span>
        </p>
        {render_slot(@inner_block)}
      </div>
      <div :if={@actions != []} class="flex shrink-0 flex-col gap-1.5">
        {render_slot(@actions)}
      </div>
    </li>
    """
  end

  defp source_label(:discogs), do: "Discogs"
  defp source_label(:musicbrainz), do: "MusicBrainz"

  defp pressing_text(result) do
    [result.format, result.label, result.catalog_number, result.country]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> nil
      parts -> Enum.join(parts, " · ")
    end
  end

  @doc "Select options for the Goldmine grading scale."
  def condition_options do
    Enum.map(Condition.values(), &{Condition.description(&1), &1})
  end

  @doc "Short label for a condition, e.g. \"VG+\"."
  def condition_label(nil), do: nil

  def condition_label(condition) do
    case Regex.run(~r/\(([^)]+)\)/, Condition.description(condition)) do
      [_, short] -> short
      _ -> to_string(condition)
    end
  end
end
