defmodule PlattensammlungWeb.AlbumComponents do
  @moduledoc """
  UI building blocks for albums and copies.
  """
  use Phoenix.Component
  use Gettext, backend: PlattensammlungWeb.Gettext

  import PlattensammlungWeb.CoreComponents, only: [icon: 1]

  alias Plattensammlung.Records.Condition

  @doc """
  Square album cover; falls back to a stylised record when there is no image.
  """
  attr :album, :map, required: true
  attr :class, :any, default: nil

  attr :morph, :boolean,
    default: false,
    doc: "the cover morphs between grid and album page (View Transitions API)"

  def cover(assigns) do
    ~H"""
    <div
      class={[
        "@container relative aspect-square overflow-hidden rounded-lg bg-base-300 shadow-sm",
        @class
      ]}
      role="img"
      aria-label={"Cover: #{@album.title}"}
      style={@morph && "view-transition-name: cover-#{@album.id}"}
    >
      <%!-- With a cover the record only fades in late: it shows when the image is broken,
           but doesn't flicker while the image loads --%>
      <div class={["grid size-full place-items-center", @album.cover_url && "delayed-fade-in"]}>
        <div class="vinyl-grooves grid aspect-square w-3/4 place-items-center rounded-full bg-neutral shadow-inner">
          <%!-- Each album gets its own label colour; without a cover it shows the initials --%>
          <div
            class="grid aspect-[1] w-[38%] place-items-center rounded-full"
            style={label_style(@album)}
          >
            <span
              :if={!@album.cover_url}
              class="font-display text-[9cqw] font-bold leading-none tracking-tight"
            >
              {initials(@album.title)}
            </span>
            <span :if={@album.cover_url} class="size-[8%] rounded-full bg-base-100"></span>
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

  @doc """
  Colours of an album's record label, derived from its title: every album gets
  its own hue, always the same one. Lightness and chroma are fixed, so the
  labels work in both themes.
  """
  def label_style(%{title: title}) do
    # to_string: album titles are case-insensitive strings (Ash.CiString)
    hue = :erlang.phash2(to_string(title), 360)
    "background-color: oklch(72% 0.12 #{hue}); color: oklch(26% 0.05 #{hue})"
  end

  # "Trans Europa Express" → "TE", "Tago Mago" → "TM", "Kind of Blue" → "KB": short
  # lower-case words ("of", "a") are skipped unless nothing else is left
  defp initials(title) do
    words = String.split(to_string(title), ~r/[^\p{L}\p{N}]+/u, trim: true)
    main = Enum.reject(words, &(String.length(&1) < 3 and &1 == String.downcase(&1)))

    if(main == [], do: words, else: main)
    |> Enum.take(2)
    |> Enum.map_join(&(&1 |> String.first() |> String.upcase()))
  end

  @doc """
  The path of a cover the app stored itself (with the optional path prefix),
  `nil` for remote covers. The browser can only read the pixels of these.
  """
  def local_cover_path(%{cover_url: "/" <> _ = path}), do: PlattensammlungWeb.Endpoint.path(path)
  def local_cover_path(_album), do: nil

  @doc """
  The record of an album as on the turntable: label in the album's colour with
  title and year. Used next to the cover on the album page; it spins on hover.
  """
  attr :album, :map, required: true
  attr :class, :any, default: nil

  def record(assigns) do
    ~H"""
    <div
      aria-hidden="true"
      class={[
        "vinyl-grooves aspect-square rounded-full bg-neutral shadow-lg ring-1 ring-white/15",
        @class
      ]}
    >
      <div
        class="@container absolute inset-[33%] grid place-items-center rounded-full text-center"
        style={label_style(@album)}
      >
        <%!-- No padding here: percentages would refer to the record, not the label --%>
        <div class="w-4/5">
          <p class="line-clamp-2 text-[12cqw] leading-tight font-semibold">{@album.title}</p>
          <p :if={@album.year} class="mt-[18cqw] text-[10cqw] opacity-80">{@album.year}</p>
        </div>
        <span class="absolute top-1/2 left-1/2 size-[7%] -translate-1/2 rounded-full bg-base-100"></span>
      </div>
    </div>
    """
  end

  # Percent-encode characters that could break out of url('…')
  # Local covers ("/covers/…") get the optional path prefix (ADR 0018)
  defp css_url("/" <> _ = path), do: path |> PlattensammlungWeb.Endpoint.path() |> encode_css()
  defp css_url(url), do: encode_css(url)

  defp encode_css(url), do: URI.encode(url, &(&1 not in ~c"'\"()\\ "))

  @doc """
  The small "← back" link above a page. A block-level flex box, so the
  spacing of the surrounding `space-y-*` applies (inline links ignore it).
  """
  attr :navigate, :string, required: true
  slot :inner_block, required: true

  def back_link(assigns) do
    ~H"""
    <.link
      navigate={@navigate}
      class="flex w-fit items-center gap-1 text-sm opacity-70 transition-opacity hover:opacity-100"
    >
      <.icon name="hero-arrow-left-micro" class="size-4" /> {render_slot(@inner_block)}
    </.link>
    """
  end

  @doc """
  An album cover as a record sleeve: on hover the sleeve shrinks a little to
  the left and the record slides out to the right, only as far as the grid gap
  (so it never covers the next album). Only on devices with a mouse.
  """
  attr :album, :map, required: true

  def sleeve(assigns) do
    ~H"""
    <div class="relative">
      <div
        aria-hidden="true"
        class="vinyl-grooves absolute inset-y-[3%] right-[3%] aspect-square rounded-full bg-neutral shadow-md ring-1 ring-white/15 transition-transform duration-300 ease-out group-hover:translate-x-5 group-focus-visible:translate-x-5 motion-reduce:transition-none"
      >
        <div class="absolute inset-[34%] rounded-full" style={label_style(@album)}>
          <div class="absolute inset-[44%] rounded-full bg-base-100"></div>
        </div>
      </div>
      <.cover
        album={@album}
        morph
        class="origin-left transition duration-300 ease-out group-hover:scale-[0.94] group-hover:shadow-lg group-focus-visible:scale-[0.94] group-focus-visible:shadow-lg motion-reduce:transition-none"
      />
    </div>
    """
  end

  @doc """
  Shows whether the actor owns an album (with number of copies), wants it, or
  neither. Expects the `owned`, `wanted` and `copy_count` calculations to be loaded.
  """
  attr :album, :map, required: true

  def status_badge(assigns) do
    ~H"""
    <span :if={@album.owned and @album.copy_count > 1} class="badge badge-sm badge-neutral">
      {@album.copy_count}×
    </span>
    <span :if={@album.wanted} class="badge badge-sm badge-accent gap-1">
      <.icon name="hero-heart-micro" class="size-3" /> {gettext("Wishlist")}
    </span>
    <span :if={!@album.owned and !@album.wanted} class="badge badge-sm badge-ghost">
      {gettext("not yours")}
    </span>
    """
  end

  @doc """
  Camera and photo barcode scanner (JS hook `BarcodeScanner`). A recognized
  code is pushed to the LiveView as the `"scanned"` event with `%{"code" => …}`.
  """
  attr :id, :string, required: true
  attr :autostart, :boolean, default: false, doc: "start the camera right away"

  def barcode_scanner(assigns) do
    ~H"""
    <%!-- The JS hook manages this element (camera, status), so LiveView must not patch it --%>
    <div
      id={@id}
      phx-hook="BarcodeScanner"
      phx-update="ignore"
      data-active="false"
      data-autostart={to_string(@autostart)}
      data-msg-needs-https={gettext("The live camera needs HTTPS. Take a photo instead.")}
      data-msg-denied={gettext("Camera access was not allowed.")}
      data-msg-failed={gettext("The camera could not be started.")}
      data-msg-aim={gettext("Hold the barcode inside the frame …")}
      data-msg-reading={gettext("Reading the photo …")}
      data-msg-no-barcode={gettext("No barcode found. Please get closer and take a sharp photo.")}
      data-msg-unreadable={gettext("The photo could not be read.")}
      class="group space-y-2"
    >
      <div class="flex flex-wrap gap-2 group-data-[active=true]:hidden">
        <button type="button" data-start class="btn btn-sm btn-neutral" id="scan-camera">
          <.icon name="hero-camera" class="size-4" /> {gettext("Scan with camera")}
        </button>
        <label class="btn btn-sm btn-ghost" id="scan-photo">
          <.icon name="hero-photo" class="size-4" /> {gettext("Take a photo")}
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
          aria-label={gettext("Close camera")}
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

  @doc "A date (or datetime) in the format of the current language."
  def format_date(date) do
    case Gettext.get_locale(PlattensammlungWeb.Gettext) do
      "de" -> Calendar.strftime(date, "%d.%m.%Y")
      _ -> Calendar.strftime(date, "%b %-d, %Y")
    end
  end

  @doc "How a user is shown to others: the display name, or a placeholder."
  def user_name(%{display_name: name}) when is_binary(name) and name != "", do: name
  def user_name(_user), do: gettext("Unnamed")

  @doc "Label of an album or copy field, e.g. in match previews."
  def field_label(:barcode), do: gettext("Barcode")
  def field_label(:label), do: gettext("Label")
  def field_label(:catalog_number), do: gettext("Catalogue number")
  def field_label(:country), do: gettext("Country")
  def field_label(:pressing_year), do: gettext("Pressing year")
  def field_label(:format), do: gettext("Format")
  def field_label(:discogs_release_id), do: gettext("Discogs pressing")
  def field_label(:musicbrainz_release_id), do: gettext("MusicBrainz pressing")
  def field_label(:year), do: gettext("Year")
  def field_label(:genres), do: gettext("Genres")
  def field_label(:cover_url), do: gettext("Cover")
  def field_label(:discogs_master_id), do: gettext("Discogs link")
  def field_label(:musicbrainz_release_group_id), do: gettext("MusicBrainz link")
  def field_label(:spotify_album_id), do: gettext("Spotify link")
  def field_label(field), do: to_string(field)

  defp source_label(:discogs), do: "Discogs"
  defp source_label(:musicbrainz), do: "MusicBrainz"

  defp pressing_text(result) do
    [Enum.join(result.format || [], ", "), result.label, result.catalog_number, result.country]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> nil
      parts -> Enum.join(parts, " · ")
    end
  end

  @doc """
  Icon for a `phx-click` button that turns into a spinner while the click is
  being handled. Use it instead of `phx-disable-with`, which restores only the
  button's text and so loses the icon. The button gets
  `phx-click-loading:pointer-events-none` against double clicks.
  """
  attr :name, :string, required: true
  attr :class, :any, default: "size-4"

  def loading_icon(assigns) do
    ~H"""
    <.icon name={@name} class={[@class, "phx-click-loading:hidden"]} />
    <span class="loading loading-spinner loading-xs hidden phx-click-loading:inline-block"></span>
    """
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
