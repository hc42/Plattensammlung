defmodule PlattensammlungWeb.AlbumLive.Index do
  @moduledoc """
  Collection, wishlist and all albums as a searchable grid of covers.
  Search term (`?q=`), the filter of the all-albums view (`?show=unassigned`)
  and the drill-down filters from the statistics (`?genre=`, `?decade=`,
  `?artist=`, `?condition=`), the order (`?sort=artist|year|added`) and the
  list view (`?view=list`) live in the URL, so every view can be bookmarked.
  Sorted by artist, the albums get letter headings and, on phones, an A–Z bar.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.{Accounts, Records}
  alias Plattensammlung.Records.Condition

  @filters ~w(genre decade artist condition)
  @sorts %{"title" => :title, "artist" => :artist, "year" => :year, "added" => :added}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_path={@current_path}>
      <div class="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 class="text-2xl font-bold">{@page_title}</h1>
          <p class="text-sm opacity-70">
            {count_text(@live_action, @count)}
            <.link
              :if={@live_action in [:collection, :wishlist]}
              navigate={~p"/albums"}
              class="link ml-2"
              id="all-albums-link"
            >
              {gettext("All albums")}
            </.link>
          </p>
          <div :if={@collector} class="join mt-2" id="collector-tabs">
            <.link
              navigate={~p"/collectors/#{@collector.id}"}
              class={["join-item btn btn-sm", @live_action == :user_collection && "btn-active"]}
            >
              {gettext("Collection")}
            </.link>
            <.link
              navigate={~p"/collectors/#{@collector.id}/wishlist"}
              class={["join-item btn btn-sm", @live_action == :user_wishlist && "btn-active"]}
            >
              {gettext("Wishlist")}
            </.link>
          </div>
        </div>

        <.form for={@search_form} id="search-form" phx-change="search" phx-submit="search">
          <label class="input w-72 max-w-full">
            <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
            <input
              type="search"
              maxlength="200"
              name="q"
              id="search-input"
              value={@search_form[:q].value}
              placeholder={gettext("Search artist or album")}
              phx-debounce="250"
              autocomplete="off"
            />
          </label>
        </.form>
      </div>

      <div class="flex flex-wrap items-center justify-between gap-3">
        <div :if={@live_action == :all} class="join" id="album-filter">
          <.link
            :for={{value, label} <- [{nil, gettext("All")}, {"unassigned", gettext("Not mine")}]}
            patch={view_path(:all, Map.put(@params, "show", value))}
            class={["join-item btn btn-sm", @show == value && "btn-active"]}
            id={"filter-#{value || "all"}"}
          >
            {label}
          </.link>
        </div>

        <div class="ml-auto flex items-center gap-2" id="list-controls">
          <form id="sort-form" phx-change="sort">
            <select name="sort" class="select select-sm w-auto" aria-label={gettext("Sort by")}>
              <option
                :for={{value, label} <- sort_options()}
                value={value}
                selected={value == @sort}
              >
                {label}
              </option>
            </select>
          </form>
          <div class="join" id="view-switch">
            <.link
              patch={view_path(@live_action, Map.put(@params, "view", "grid"))}
              class={["join-item btn btn-sm btn-square", @view != "list" && "btn-active"]}
              aria-label={gettext("Show as grid")}
              aria-pressed={to_string(@view != "list")}
              id="view-grid"
            >
              <.icon name="hero-squares-2x2" class="size-4" />
            </.link>
            <.link
              patch={view_path(@live_action, Map.put(@params, "view", "list"))}
              class={["join-item btn btn-sm btn-square", @view == "list" && "btn-active"]}
              aria-label={gettext("Show as list")}
              aria-pressed={to_string(@view == "list")}
              id="view-list"
            >
              <.icon name="hero-list-bullet" class="size-4" />
            </.link>
          </div>
        </div>
      </div>

      <div
        :if={active_filters(@params) != []}
        class="flex flex-wrap items-center gap-2"
        id="active-filters"
      >
        <span class="text-sm opacity-70">{gettext("Filtered:")}</span>
        <.link
          :for={{key, value} <- active_filters(@params)}
          patch={view_path(@live_action, Map.delete(@params, key))}
          class="badge badge-lg badge-primary gap-1"
          id={"active-filter-#{key}"}
          aria-label={gettext("Remove filter %{filter}", filter: filter_label(key, value))}
        >
          {filter_label(key, value)} <.icon name="hero-x-mark-micro" class="size-4" />
        </.link>
      </div>

      <%!-- Behind the top of the page: the colour of the album under the mouse (hook ListTint).
           Static, so LiveView patches leave the colour the hook set alone --%>
      <div
        id="list-tint"
        class="cover-tint soft pointer-events-none absolute inset-x-0 top-0 -z-10 h-[40rem]"
      >
      </div>

      <%!-- Remembers this list (view, order, search) for the back link of the album page --%>
      <div
        id="list-memory"
        phx-hook="RememberList"
        data-url={view_path(@live_action, @params)}
        data-label={@page_title}
        data-view={@view}
        data-sort={@sort}
        hidden
      >
      </div>

      <div
        id="albums"
        phx-update="stream"
        phx-hook="ListTint"
        data-tint-target="list-tint"
        class={
          [
            if(@view == "list",
              do: "divide-y divide-base-300",
              else: "grid grid-cols-2 gap-x-6 gap-y-8 sm:grid-cols-3 md:grid-cols-4 lg:grid-cols-5"
            ),
            # Room for the A–Z bar on phones
            @letters != [] && "pr-5 sm:pr-0"
          ]
        }
      >
        <div class="col-span-full hidden py-16 text-center only:block" id="albums-empty">
          <.icon name="hero-musical-note" class="mx-auto size-10 opacity-30" />
          <p class="mt-2 opacity-70">
            {empty_text(@live_action, @query || (active_filters(@params) != [] && :filtered) || nil)}
          </p>
          <.link
            :if={!@query and !@collector}
            navigate={~p"/import"}
            class="btn btn-primary btn-sm mt-4"
          >
            {gettext("Add a record")}
          </.link>
        </div>

        <%= for {id, item} <- @streams.albums do %>
          <%!-- Letter headings when sorted by artist (targets of the A–Z bar) --%>
          <h2
            :if={is_map_key(item, :letter)}
            id={id}
            class="scroll-mt-24 pt-5 pb-1 font-display text-lg font-bold text-primary"
          >
            {item.letter}
          </h2>
          <.link
            :if={!is_map_key(item, :letter) and @view == "list"}
            id={id}
            navigate={~p"/albums/#{item}"}
            class="group list-row -mx-3 flex scroll-mt-24 items-center gap-4 rounded-lg px-3 py-3"
            data-cover={local_cover_path(item)}
            data-color={label_color(item)}
          >
            <.cover album={item} morph class="size-14 shrink-0" />
            <div class="min-w-0 flex-1">
              <p class="truncate font-medium leading-tight" title={item.title}>{item.title}</p>
              <p class="truncate text-sm opacity-70">{item.artist.name}</p>
            </div>
            <div class="flex shrink-0 items-center gap-1.5 text-xs opacity-60">
              <span :if={item.year} class="hidden sm:inline">{item.year}</span>
              <.status_badge album={item} />
            </div>
          </.link>
          <.link
            :if={!is_map_key(item, :letter) and @view != "list"}
            id={id}
            navigate={~p"/albums/#{item}"}
            class="group block scroll-mt-24"
            data-cover={local_cover_path(item)}
            data-color={label_color(item)}
          >
            <.sleeve album={item} />
            <div class="mt-2 space-y-0.5">
              <p class="truncate font-medium leading-tight" title={item.title}>{item.title}</p>
              <p class="truncate text-sm opacity-70">{item.artist.name}</p>
              <div class="flex items-center gap-1.5 text-xs opacity-60">
                <span :if={item.year}>{item.year}</span>
                <.status_badge album={item} />
              </div>
            </div>
          </.link>
        <% end %>
      </div>

      <%!-- Phones, sorted by artist: jump to a letter, like in the Contacts app --%>
      <nav
        :if={@letters != []}
        id="letter-bar"
        class="fixed top-1/2 right-0.5 z-10 flex -translate-y-1/2 flex-col items-center rounded-full bg-base-100/80 py-1 backdrop-blur sm:hidden"
        aria-label={gettext("Jump to letter")}
      >
        <a
          :for={{letter, id} <- @letters}
          href={"##{id}"}
          class="px-1.5 text-[0.6875rem] leading-4 font-semibold text-primary"
        >
          {letter}
        </a>
      </nav>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    # The view and order chosen last in this browser tab (hook RememberList, sent
    # by app.js as connect params); used when the URL doesn't name them
    prefs = (connected?(socket) && get_connect_params(socket)["list_prefs"]) || %{}

    {:ok,
     socket
     |> assign(:preferred_sort, valid_sort(prefs["sort"]))
     |> assign(:preferred_view, valid_view(prefs["view"]))}
  end

  @impl true
  def handle_params(params, _url, socket) do
    query = blank_to_nil(params["q"])
    show = if params["show"] == "unassigned", do: "unassigned", else: nil
    sort = valid_sort(params["sort"]) || socket.assigns.preferred_sort || "title"
    view = valid_view(params["view"]) || socket.assigns.preferred_view || "grid"
    action = socket.assigns.live_action

    filters =
      for key <- @filters, value = blank_to_nil(params[key]), into: %{}, do: {key, value}

    # Someone else's collection (read-only), otherwise the own albums
    collector =
      params["user_id"] &&
        Accounts.get_collector!(params["user_id"], actor: socket.assigns.current_user)

    search_params =
      filters
      |> Map.put("order", Map.get(@sorts, sort, :title))
      |> then(&if collector, do: Map.put(&1, "owner_id", collector.id), else: &1)

    albums =
      Records.search_albums!(query, status(action, show), search_params,
        load: [:owned, :wanted, :copy_count],
        actor: socket.assigns.current_user
      )

    {:noreply,
     socket
     |> assign(:collector, collector)
     |> assign(:page_title, page_title(action, collector))
     |> assign(
       :params,
       Map.merge(filters, %{
         "q" => query,
         "show" => show,
         # Only what the URL names; the rest comes from the preferences again
         "sort" => valid_sort(params["sort"]),
         "view" => valid_view(params["view"]),
         "user_id" => params["user_id"]
       })
     )
     |> assign(:query, query)
     |> assign(:show, show)
     |> assign(:sort, sort)
     |> assign(:view, view)
     |> assign(:count, length(albums))
     |> assign(:search_form, to_form(%{"q" => query}))
     |> assign_items(albums, sort, view)}
  end

  # Sorted by artist: the A–Z bar jumps to the first album of each letter; the
  # list also gets a heading per letter (in the grid it would waste whole rows)
  defp assign_items(socket, albums, "artist", view) do
    groups = albums |> Enum.chunk_by(&letter/1) |> Enum.with_index()

    # In the list the bar jumps to the heading, in the grid to the first album
    letters =
      groups
      |> Enum.map(fn {[first | _], index} ->
        {letter(first),
         if(view == "list", do: "albums-letter-#{index}", else: "albums-#{first.id}")}
      end)
      |> Enum.uniq_by(&elem(&1, 0))

    items =
      if view == "list" do
        Enum.flat_map(groups, fn {[first | _] = group, index} ->
          [%{id: "letter-#{index}", letter: letter(first)} | group]
        end)
      else
        albums
      end

    socket |> assign(:letters, letters) |> stream(:albums, items, reset: true)
  end

  defp assign_items(socket, albums, _sort, _view) do
    socket |> assign(:letters, []) |> stream(:albums, albums, reset: true)
  end

  defp letter(album) do
    name = album.artist.sort_name || to_string(album.artist.name)
    first = name |> String.first() |> to_string() |> String.upcase()
    if first =~ ~r/^\p{L}$/u, do: first, else: "#"
  end

  # URL parameters and connect params are user input: only known values
  defp valid_sort(sort) when is_map_key(@sorts, sort), do: sort
  defp valid_sort(_sort), do: nil

  defp valid_view(view) when view in ["grid", "list"], do: view
  defp valid_view(_view), do: nil

  defp sort_options do
    [
      {"title", gettext("Title")},
      {"artist", gettext("Artist")},
      {"year", gettext("Year")},
      {"added", gettext("Recently added")}
    ]
  end

  @impl true
  def handle_event("sort", %{"sort" => sort}, socket) do
    params = Map.put(socket.assigns.params, "sort", valid_sort(sort))

    {:noreply, push_patch(socket, to: view_path(socket.assigns.live_action, params))}
  end

  def handle_event("search", %{"q" => q}, socket) do
    params = Map.put(socket.assigns.params, "q", blank_to_nil(q))

    {:noreply,
     push_patch(socket, to: view_path(socket.assigns.live_action, params), replace: true)}
  end

  defp status(:all, "unassigned"), do: :other
  defp status(:all, nil), do: nil
  defp status(:user_collection, _show), do: :collection
  defp status(:user_wishlist, _show), do: :wishlist
  defp status(action, _show), do: action

  # URL of a view with the given params (nil values are left out)
  defp view_path(:all, params), do: ~p"/albums" <> query_string(params)
  defp view_path(:wishlist, params), do: ~p"/wishlist" <> query_string(Map.delete(params, "show"))
  defp view_path(:collection, params), do: ~p"/" <> query_string(Map.delete(params, "show"))

  defp view_path(:user_collection, %{"user_id" => id} = params),
    do: ~p"/collectors/#{id}" <> query_string(Map.delete(params, "show"))

  defp view_path(:user_wishlist, %{"user_id" => id} = params),
    do: ~p"/collectors/#{id}/wishlist" <> query_string(Map.delete(params, "show"))

  defp active_filters(params) do
    for key <- @filters, value = params[key], do: {key, value}
  end

  defp filter_label("genre", genre), do: genre
  defp filter_label("decade", "unknown"), do: gettext("Without year")
  defp filter_label("decade", decade), do: gettext("%{decade}s", decade: decade)
  defp filter_label("artist", artist), do: artist
  defp filter_label("condition", "none"), do: gettext("Without condition")

  defp filter_label("condition", value) do
    case Condition.match(value) do
      {:ok, grade} -> gettext("Condition: %{grade}", grade: Condition.description(grade))
      _ -> value
    end
  end

  # The collector id is part of the path, not of the query
  defp query_string(params) do
    case params
         |> Map.delete("user_id")
         |> Enum.reject(fn {_key, value} -> is_nil(value) end)
         |> Enum.sort() do
      [] -> ""
      params -> "?" <> URI.encode_query(params)
    end
  end

  # URL parameters are user input: only strings, cut to the 200 characters
  # the search action accepts (?q[]=… or an endless ?q= must not crash the page)
  defp blank_to_nil(value) when is_binary(value) do
    case value |> String.trim() |> String.slice(0, 200) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp blank_to_nil(_value), do: nil

  defp page_title(:collection, _collector), do: gettext("Collection")
  defp page_title(:wishlist, _collector), do: gettext("Wishlist")
  defp page_title(:all, _collector), do: gettext("All albums")

  defp page_title(:user_collection, collector),
    do: gettext("Collection of %{name}", name: user_name(collector))

  defp page_title(:user_wishlist, collector),
    do: gettext("Wishlist of %{name}", name: user_name(collector))

  defp count_text(action, n) when action in [:wishlist, :user_wishlist],
    do: ngettext("1 wish", "%{count} wishes", n)

  defp count_text(_action, n), do: ngettext("1 album", "%{count} albums", n)

  defp empty_text(_action, query) when is_binary(query),
    do: gettext("Nothing found for “%{query}”.", query: query)

  defp empty_text(_action, :filtered), do: gettext("No albums with these filters.")
  defp empty_text(:collection, nil), do: gettext("No records in the collection yet.")
  defp empty_text(:wishlist, nil), do: gettext("The wishlist is empty.")
  defp empty_text(:all, nil), do: gettext("No albums in this view.")
  defp empty_text(:user_collection, nil), do: gettext("No records in this collection yet.")
  defp empty_text(:user_wishlist, nil), do: gettext("This wishlist is empty.")
end
