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
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-2xl space-y-6">
        <div>
          <h1 class="text-2xl font-bold">Platte erfassen</h1>
          <p class="text-sm opacity-70">
            Barcode eintippen oder scannen, oder nach Künstler und Titel suchen.
          </p>
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

  def handle_event("import", %{"index" => index, "target" => target}, socket) do
    item = Map.fetch!(socket.assigns.results, String.to_integer(index))

    case add_album(item, target) do
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
        %{index: index, result: result, existing: existing_album(result)}
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

    socket
    |> reset_results()
    |> assign(:search_form, to_form(%{"query" => query}))
    |> assign(:searched?, true)
    |> assign(:loading, true)
    |> assign(:owned_pressing, barcode && List.first(Records.find_by_barcode!(barcode)))
    |> start_async(:lookup, fn -> Records.lookup_albums(query) end)
  end

  defp reset_results(socket) do
    socket
    |> assign(:loading, false)
    |> assign(:error, false)
    |> assign(:owned_pressing, nil)
    |> assign(:results, %{})
    |> stream(:results, [], reset: true, dom_id: &"result-#{&1.index}")
  end

  defp existing_album(result) do
    result.artist_name
    |> Records.find_duplicates!(result.title, load: [:owned])
    |> List.first()
  end

  # Already known album: add another copy (collection) or just open it
  defp add_album(%{existing: %{} = album, result: result}, "collection") do
    with {:ok, _copy} <- Records.add_copy(album.id, Lookup.copy_attrs(result)) do
      {:ok, album, "Exemplar von „#{album.title}“ hinzugefügt."}
    end
  end

  defp add_album(%{existing: %{} = album}, "wishlist") do
    {:ok, album, "„#{album.title}“ ist schon erfasst."}
  end

  defp add_album(%{result: result}, "collection") do
    attrs = result |> Lookup.album_attrs() |> Map.put(:copy, Lookup.copy_attrs(result))

    with {:ok, album} <- Records.add_to_collection(result.artist_name, result.title, attrs) do
      {:ok, album, "„#{album.title}“ ist jetzt in deiner Sammlung."}
    end
  end

  defp add_album(%{result: result}, "wishlist") do
    attrs = Lookup.album_attrs(result)

    with {:ok, album} <- Records.add_to_wishlist(result.artist_name, result.title, attrs) do
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
