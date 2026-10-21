defmodule PlattensammlungWeb.AlbumLive.Index do
  @moduledoc """
  Collection and wishlist as a searchable grid of covers.
  The search term lives in the URL (`?q=`), so results can be bookmarked.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.Records

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold">{@page_title}</h1>
          <p class="text-sm opacity-70">{count_text(@live_action, @count)}</p>
        </div>

        <.form for={@search_form} id="search-form" phx-change="search" phx-submit="search">
          <label class="input w-72 max-w-full">
            <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
            <input
              type="search"
              name="q"
              id="search-input"
              value={@search_form[:q].value}
              placeholder="Künstler oder Album suchen"
              phx-debounce="250"
              autocomplete="off"
            />
          </label>
        </.form>
      </div>

      <div
        id="albums"
        phx-update="stream"
        class="grid grid-cols-2 gap-x-4 gap-y-6 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5"
      >
        <div class="col-span-full hidden py-16 text-center only:block" id="albums-empty">
          <.icon name="hero-musical-note" class="mx-auto size-10 opacity-30" />
          <p class="mt-2 opacity-70">{empty_text(@live_action, @query)}</p>
          <.link :if={!@query} navigate={~p"/import"} class="btn btn-primary btn-sm mt-4">
            Platte erfassen
          </.link>
        </div>

        <.link
          :for={{id, album} <- @streams.albums}
          id={id}
          navigate={~p"/albums/#{album}"}
          class="group block"
        >
          <.cover
            album={album}
            class="transition duration-200 group-hover:-translate-y-1 group-hover:shadow-lg"
          />
          <div class="mt-2 space-y-0.5">
            <p class="truncate font-medium leading-tight" title={album.title}>{album.title}</p>
            <p class="truncate text-sm opacity-70">{album.artist.name}</p>
            <div class="flex items-center gap-1.5 text-xs opacity-60">
              <span :if={album.year}>{album.year}</span>
              <.status_badge album={album} />
            </div>
          </div>
        </.link>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = blank_to_nil(params["q"])
    status = socket.assigns.live_action

    albums =
      Records.search_albums!(query, status,
        load: [:owned, :copy_count],
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:page_title, page_title(status))
     |> assign(:query, query)
     |> assign(:count, length(albums))
     |> assign(:search_form, to_form(%{"q" => query}))
     |> stream(:albums, albums, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    path = if socket.assigns.live_action == :wishlist, do: ~p"/wishlist", else: ~p"/"
    params = if blank_to_nil(q), do: %{q: q}, else: %{}

    {:noreply, push_patch(socket, to: path <> query_string(params), replace: true)}
  end

  defp query_string(params) when params == %{}, do: ""
  defp query_string(params), do: "?" <> URI.encode_query(params)

  defp blank_to_nil(value) do
    case value && String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp page_title(:collection), do: "Sammlung"
  defp page_title(:wishlist), do: "Wunschliste"

  defp count_text(:collection, 1), do: "1 Album"
  defp count_text(:collection, n), do: "#{n} Alben"
  defp count_text(:wishlist, 1), do: "1 Wunsch"
  defp count_text(:wishlist, n), do: "#{n} Wünsche"

  defp empty_text(_action, query) when is_binary(query), do: "Nichts gefunden für „#{query}“."
  defp empty_text(:collection, nil), do: "Noch keine Platten in der Sammlung."
  defp empty_text(:wishlist, nil), do: "Die Wunschliste ist leer."
end
