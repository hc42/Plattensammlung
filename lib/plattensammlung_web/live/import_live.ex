defmodule PlattensammlungWeb.ImportLive do
  @moduledoc """
  Finds an album on Discogs/MusicBrainz by barcode or artist and title and
  adds it with one click (see ADR 0007). The lookup runs asynchronously with
  `start_async`, so the page stays responsive while external services answer.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.{Lookup, Records}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-2xl space-y-6">
        <div>
          <h1 class="text-2xl font-bold">Platte erfassen</h1>
          <p class="text-sm opacity-70">
            Barcode scannen oder eintippen, oder nach Künstler und Titel suchen.
          </p>
        </div>

        <%!-- The JS hook manages this element (camera, status), so LiveView must not patch it --%>
        <div
          id="barcode-scanner"
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

        <.form for={@search_form} id="lookup-form" phx-submit="lookup" class="flex gap-2">
          <label class="input flex-1">
            <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
            <input
              type="search"
              name="query"
              id="lookup-input"
              value={@search_form[:query].value}
              placeholder="z. B. 0602547288530 oder Beatles Abbey Road"
              autocomplete="off"
              autofocus
            />
          </label>
          <.button variant="primary" id="lookup-submit" disabled={@loading}>Suchen</.button>
        </.form>

        <p :if={not @discogs?} class="text-xs opacity-60" id="discogs-hint">
          Discogs ist nicht eingerichtet (Umgebungsvariable <code>DISCOGS_TOKEN</code>),
          es wird nur MusicBrainz durchsucht.
        </p>

        <div :if={@loading} id="lookup-loading" class="flex items-center gap-2 py-6 opacity-70">
          <span class="loading loading-spinner loading-sm"></span> Suche läuft …
        </div>

        <div :if={@owned_pressing} id="owned-pressing" class="alert alert-success alert-soft">
          <.icon name="hero-check-circle" class="size-5" />
          <span>
            Genau diese Pressung hast du schon:
            <.link navigate={~p"/albums/#{@owned_pressing}"} class="link font-medium">
              {@owned_pressing.title}
            </.link>
          </span>
        </div>

        <p :if={@error} id="lookup-error" class="alert alert-error alert-soft">
          Die Suche hat nicht geklappt. Bitte später noch einmal versuchen.
        </p>

        <div :if={@searched? and not @loading and @results == %{} and !@error} id="no-results">
          <p class="opacity-70">Nichts gefunden für „{@search_form[:query].value}“.</p>
        </div>

        <ul id="results" phx-update="stream" class="divide-y divide-base-300">
          <li :for={{dom_id, item} <- @streams.results} id={dom_id} class="flex gap-4 py-4">
            <.cover
              album={%{cover_url: item.result.thumb_url, title: item.result.title}}
              class="size-20 shrink-0"
            />
            <div class="min-w-0 flex-1 space-y-1">
              <p class="truncate font-medium">{item.result.title}</p>
              <p class="truncate text-sm opacity-70">{item.result.artist_name}</p>
              <p class="flex flex-wrap items-center gap-1.5 text-xs opacity-60">
                <span :if={item.result.year}>{item.result.year}</span>
                <span class="badge badge-ghost badge-xs">{source_label(item.result.source)}</span>
                <span :if={pressing_text(item.result)}>{pressing_text(item.result)}</span>
              </p>
              <p :if={item.existing} class="text-xs">
                <.link navigate={~p"/albums/#{item.existing}"} class="link link-accent">
                  {if item.existing.owned, do: "Hast du schon", else: "Steht auf deiner Wunschliste"}
                </.link>
              </p>
            </div>
            <div class="flex shrink-0 flex-col gap-1.5">
              <button
                phx-click="import"
                phx-value-index={item.index}
                phx-value-target="collection"
                phx-disable-with="…"
                class="btn btn-primary btn-sm"
                id={"import-collection-#{item.index}"}
              >
                <.icon name="hero-plus-micro" class="size-4" />
                {if item.existing && item.existing.owned, do: "Exemplar", else: "Sammlung"}
              </button>
              <button
                :if={!item.existing}
                phx-click="import"
                phx-value-index={item.index}
                phx-value-target="wishlist"
                phx-disable-with="…"
                class="btn btn-ghost btn-sm"
                id={"import-wishlist-#{item.index}"}
              >
                <.icon name="hero-heart-micro" class="size-4" /> Wunsch
              </button>
            </div>
          </li>
        </ul>

        <p class="text-sm opacity-70">
          Nicht dabei?
          <.link navigate={~p"/albums/new"} class="link" id="manual-entry">Manuell erfassen</.link>
        </p>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Platte erfassen")
     |> assign(:discogs?, Lookup.Discogs.configured?())
     |> assign(:search_form, to_form(%{"query" => ""}))
     |> reset_results()
     |> assign(:searched?, false)}
  end

  @impl true
  def handle_params(%{"q" => query}, _url, socket) when query != "" do
    {:noreply, start_lookup(socket, query)}
  end

  def handle_params(_params, _url, socket), do: {:noreply, socket}

  @impl true
  def handle_event("lookup", %{"query" => query}, socket) do
    {:noreply, push_patch(socket, to: ~p"/import?#{[q: query]}")}
  end

  # Sent by the BarcodeScanner hook (assets/js/hooks/barcode_scanner.js)
  def handle_event("scanned", %{"code" => code}, socket) do
    case Lookup.barcode(code) do
      nil -> {:noreply, put_flash(socket, :error, "Das sieht nicht nach einem Barcode aus.")}
      barcode -> {:noreply, push_patch(socket, to: ~p"/import?#{[q: barcode]}")}
    end
  end

  def handle_event("import", %{"index" => index, "target" => target}, socket) do
    item = Map.fetch!(socket.assigns.results, String.to_integer(index))

    case add_album(item, target, socket.assigns.current_user) do
      {:ok, album, message} ->
        {:noreply,
         socket
         |> put_flash(:info, message)
         |> push_navigate(to: ~p"/albums/#{album}")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Das Album konnte nicht angelegt werden.")}
    end
  end

  @impl true
  def handle_async(:lookup, {:ok, {:ok, results}}, socket) do
    items =
      results
      |> Enum.with_index()
      |> Enum.map(fn {result, index} ->
        %{
          index: index,
          result: result,
          existing: existing_album(result, socket.assigns.current_user)
        }
      end)

    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:results, Map.new(items, &{&1.index, &1}))
     |> stream(:results, items, reset: true, dom_id: &"result-#{&1.index}")}
  end

  def handle_async(:lookup, _failure, socket) do
    {:noreply, socket |> assign(:loading, false) |> assign(:error, true)}
  end

  defp start_lookup(socket, query) do
    barcode = Lookup.barcode(query)
    actor = socket.assigns.current_user

    socket
    |> reset_results()
    |> assign(:search_form, to_form(%{"query" => query}))
    |> assign(:searched?, true)
    |> assign(:loading, true)
    |> assign(
      :owned_pressing,
      barcode && List.first(Records.find_by_barcode!(barcode, actor: actor))
    )
    |> start_async(:lookup, fn -> Records.lookup_albums(query, actor: actor) end)
  end

  defp reset_results(socket) do
    socket
    |> assign(:loading, false)
    |> assign(:error, false)
    |> assign(:owned_pressing, nil)
    |> assign(:results, %{})
    |> stream(:results, [], reset: true, dom_id: &"result-#{&1.index}")
  end

  defp existing_album(result, actor) do
    result.artist_name
    |> Records.find_duplicates!(result.title, load: [:owned], actor: actor)
    |> List.first()
  end

  # Already known album: add another copy (collection) or just open it
  defp add_album(%{existing: %{} = album, result: result}, "collection", actor) do
    with {:ok, _copy} <- Records.add_copy(album.id, Lookup.copy_attrs(result), actor: actor) do
      {:ok, album, "Exemplar von „#{album.title}“ hinzugefügt."}
    end
  end

  defp add_album(%{existing: %{} = album}, "wishlist", _actor) do
    {:ok, album, "„#{album.title}“ ist schon erfasst."}
  end

  defp add_album(%{result: result}, "collection", actor) do
    attrs = result |> Lookup.album_attrs() |> Map.put(:copy, Lookup.copy_attrs(result))

    with {:ok, album} <-
           Records.add_to_collection(result.artist_name, result.title, attrs, actor: actor) do
      {:ok, album, "„#{album.title}“ ist jetzt in deiner Sammlung."}
    end
  end

  defp add_album(%{result: result}, "wishlist", actor) do
    attrs = Lookup.album_attrs(result)

    with {:ok, album} <-
           Records.add_to_wishlist(result.artist_name, result.title, attrs, actor: actor) do
      {:ok, album, "„#{album.title}“ steht auf der Wunschliste."}
    end
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
end
