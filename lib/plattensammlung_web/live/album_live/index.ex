defmodule PlattensammlungWeb.AlbumLive.Index do
  @moduledoc """
  Collection, wishlist and all albums as a searchable grid of covers.
  Search term (`?q=`) and the filter of the all-albums view (`?show=unassigned`)
  live in the URL, so results can be bookmarked.
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
          <p class="text-sm opacity-70">
            {count_text(@live_action, @count)}
            <.link
              :if={@live_action != :all}
              navigate={~p"/albums"}
              class="link ml-2"
              id="all-albums-link"
            >
              Alle Alben
            </.link>
          </p>
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

      <div :if={@live_action == :all} class="join" id="album-filter">
        <.link
          :for={{value, label} <- [{nil, "Alle"}, {"unassigned", "Ohne Exemplar und Wunsch"}]}
          patch={all_path(@query, value)}
          class={["join-item btn btn-sm", @show == value && "btn-active"]}
          id={"filter-#{value || "all"}"}
        >
          {label}
        </.link>
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
    show = if params["show"] == "unassigned", do: "unassigned", else: nil
    action = socket.assigns.live_action

    albums =
      Records.search_albums!(query, status(action, show),
        load: [:owned, :copy_count],
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:page_title, page_title(action))
     |> assign(:query, query)
     |> assign(:show, show)
     |> assign(:count, length(albums))
     |> assign(:search_form, to_form(%{"q" => query}))
     |> stream(:albums, albums, reset: true)}
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    path =
      case socket.assigns.live_action do
        :all -> all_path(blank_to_nil(q), socket.assigns.show)
        :wishlist -> ~p"/wishlist" <> query_string(%{q: blank_to_nil(q)})
        :collection -> ~p"/" <> query_string(%{q: blank_to_nil(q)})
      end

    {:noreply, push_patch(socket, to: path, replace: true)}
  end

  defp status(:all, "unassigned"), do: :other
  defp status(:all, nil), do: nil
  defp status(action, _show), do: action

  defp all_path(query, show), do: ~p"/albums" <> query_string(%{q: query, show: show})

  defp query_string(params) do
    case params |> Enum.reject(fn {_key, value} -> is_nil(value) end) do
      [] -> ""
      params -> "?" <> URI.encode_query(params)
    end
  end

  defp blank_to_nil(value) do
    case value && String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp page_title(:collection), do: "Sammlung"
  defp page_title(:wishlist), do: "Wunschliste"
  defp page_title(:all), do: "Alle Alben"

  defp count_text(:collection, 1), do: "1 Album"
  defp count_text(:collection, n), do: "#{n} Alben"
  defp count_text(:wishlist, 1), do: "1 Wunsch"
  defp count_text(:wishlist, n), do: "#{n} Wünsche"
  defp count_text(:all, 1), do: "1 Album"
  defp count_text(:all, n), do: "#{n} Alben"

  defp empty_text(_action, query) when is_binary(query), do: "Nichts gefunden für „#{query}“."
  defp empty_text(:collection, nil), do: "Noch keine Platten in der Sammlung."
  defp empty_text(:wishlist, nil), do: "Die Wunschliste ist leer."
  defp empty_text(:all, nil), do: "Keine Alben in dieser Ansicht."
end
