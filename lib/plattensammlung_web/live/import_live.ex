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
            Barcode scannen oder eintippen, nach Künstler und Titel suchen oder einen
            Spotify-Album-Link einfügen.
          </p>
        </div>

        <.barcode_scanner id="barcode-scanner" />

        <.form for={@search_form} id="lookup-form" phx-submit="lookup" class="flex gap-2">
          <label class="input flex-1">
            <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
            <input
              type="search"
              maxlength="200"
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
          <.lookup_result :for={{dom_id, item} <- @streams.results} id={dom_id} result={item.result}>
            <p :if={item.existing} class="text-xs">
              <.link navigate={~p"/albums/#{item.existing}"} class="link link-accent">
                {existing_label(item.existing)}
              </.link>
            </p>
            <:actions>
              <button
                phx-click="import"
                phx-value-index={item.index}
                phx-value-target="collection"
                class="btn btn-primary btn-sm phx-click-loading:pointer-events-none"
                id={"import-collection-#{item.index}"}
              >
                <.loading_icon name="hero-plus-micro" />
                {if item.existing && item.existing.owned, do: "Exemplar", else: "Sammlung"}
              </button>
              <button
                :if={!(item.existing && (item.existing.owned or item.existing.wanted))}
                phx-click="import"
                phx-value-index={item.index}
                phx-value-target="wishlist"
                class="btn btn-ghost btn-sm phx-click-loading:pointer-events-none"
                id={"import-wishlist-#{item.index}"}
              >
                <.loading_icon name="hero-heart-micro" /> Wunsch
              </button>
            </:actions>
          </.lookup_result>
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
  # Codes are barcodes or, from QR codes, Spotify album links
  def handle_event("scanned", %{"code" => code}, socket) do
    cond do
      barcode = Lookup.barcode(code) ->
        {:noreply, push_patch(socket, to: ~p"/import?#{[q: barcode]}")}

      Lookup.spotify_link(code) ->
        {:noreply, push_patch(socket, to: ~p"/import?#{[q: String.trim(code)]}")}

      true ->
        {:noreply, put_flash(socket, :error, "Das sieht nicht nach einem Barcode aus.")}
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
    |> Records.find_duplicates!(result.title, load: [:owned, :wanted], actor: actor)
    |> List.first()
  end

  # add_to_collection/add_to_wishlist reuse an album that is already in the
  # shared catalog and only fill its gaps (ADR 0016)
  defp add_album(%{result: result, existing: existing}, "collection", actor) do
    attrs = result |> Lookup.album_attrs() |> Map.put(:copy, Lookup.copy_attrs(result))

    with {:ok, album} <-
           Records.add_to_collection(result.artist_name, result.title, attrs, actor: actor) do
      message =
        if existing && existing.owned,
          do: "Exemplar von „#{album.title}“ hinzugefügt.",
          else: "„#{album.title}“ ist jetzt in deiner Sammlung."

      {:ok, album, message}
    end
  end

  defp add_album(%{result: result}, "wishlist", actor) do
    attrs = Lookup.album_attrs(result)

    with {:ok, album} <-
           Records.add_to_wishlist(result.artist_name, result.title, attrs, actor: actor) do
      {:ok, album, "„#{album.title}“ steht auf der Wunschliste."}
    end
  end

  defp existing_label(%{owned: true}), do: "Hast du schon"
  defp existing_label(%{wanted: true}), do: "Steht auf deiner Wunschliste"
  defp existing_label(_album), do: "Bei anderen Sammlern"
end
