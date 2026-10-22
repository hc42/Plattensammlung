defmodule PlattensammlungWeb.AlbumLive.Merge do
  @moduledoc """
  Merges two catalogue entries of the same record (`Records.merge_albums/2`,
  ADR 0024). The other entry is searched in the whole catalogue, prefilled with
  the title; then both are shown side by side and the user picks the one to keep.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.Records
  alias PlattensammlungWeb.Ownership

  @load [:artist, :owned, :wanted, :editable, :copies, :wishes]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_path={@current_path}>
      <div class="mx-auto max-w-2xl space-y-6">
        <div>
          <.back_link navigate={~p"/albums/#{@album}"}>{@album.title}</.back_link>
          <h1 class="mt-3 text-2xl font-bold">{gettext("Merge duplicate")}</h1>
          <p class="text-sm opacity-70">
            {gettext(
              "Choose the other entry of the same record. Copies and wishes of all collectors move to the album you keep, its empty fields are filled from the other one, and the other one is deleted."
            )}
          </p>
        </div>

        <%= if @other do %>
          <form id="merge-form" phx-submit="merge" class="space-y-4">
            <div class="grid gap-4 sm:grid-cols-2">
              <label
                :for={album <- [@album, @other]}
                class="cursor-pointer space-y-2 rounded-lg border border-base-300 p-3 has-checked:border-primary has-checked:ring-2 has-checked:ring-primary/30"
                id={"keep-#{album.id}"}
              >
                <.cover album={album} class="w-full" />
                <p class="font-medium leading-tight">{album.title}</p>
                <p class="text-sm opacity-70">
                  {album.artist.name} <span :if={album.year}>· {album.year}</span>
                </p>
                <p class="text-xs opacity-60">{holder_text(album)}</p>
                <span class="flex items-center gap-2 text-sm font-medium">
                  <input
                    type="radio"
                    name="keep"
                    value={album.id}
                    checked={album.id == @keep}
                    class="radio radio-primary radio-sm"
                  />
                  {gettext("Keep this one")}
                </span>
              </label>
            </div>
            <div class="flex flex-wrap gap-2">
              <button
                class="btn btn-primary"
                id="merge-button"
                data-confirm={gettext("Merge the two albums? This can't be undone.")}
              >
                <.icon name="hero-arrows-pointing-in" class="size-4" /> {gettext("Merge")}
              </button>
              <button type="button" phx-click="unchoose" class="btn btn-ghost">
                {gettext("Choose another")}
              </button>
            </div>
          </form>
        <% else %>
          <.form for={@search_form} id="merge-search" phx-change="search" phx-submit="search">
            <label class="input w-full">
              <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
              <input
                type="search"
                name="q"
                maxlength="200"
                value={@search_form[:q].value}
                placeholder={gettext("Search artist or album")}
                phx-debounce="250"
                autocomplete="off"
                id="merge-query"
              />
            </label>
          </.form>

          <p :if={@candidates == []} class="py-6 opacity-70" id="no-candidates">
            {gettext("No other album found. Try another search term.")}
          </p>

          <ul id="candidates" class="divide-y divide-base-300">
            <li
              :for={album <- @candidates}
              id={"candidate-#{album.id}"}
              class="flex items-center gap-4 py-3"
            >
              <.cover album={album} class="size-14 shrink-0" />
              <div class="min-w-0 flex-1">
                <p class="truncate font-medium">{album.title}</p>
                <p class="truncate text-sm opacity-70">
                  {album.artist.name} <span :if={album.year}>· {album.year}</span>
                </p>
              </div>
              <button
                type="button"
                phx-click="choose"
                phx-value-id={album.id}
                class="btn btn-sm"
                id={"choose-#{album.id}"}
              >
                {gettext("Choose")}
              </button>
            </li>
          </ul>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    album = Records.get_album!(id, load: @load, actor: socket.assigns.current_user)

    case Ownership.require_editable(socket, album) do
      :ok ->
        {:ok,
         socket
         |> assign(:page_title, gettext("Merge duplicate"))
         |> assign(:album, album)
         |> assign(:other, nil)
         |> assign(:keep, album.id)
         |> search(to_string(album.title))}

      {:redirect, socket} ->
        {:ok, socket}
    end
  end

  @impl true
  def handle_event("search", %{"q" => q}, socket) do
    {:noreply, search(socket, q |> to_string() |> String.slice(0, 200))}
  end

  def handle_event("choose", %{"id" => id}, socket) do
    case Enum.find(socket.assigns.candidates, &(&1.id == id)) do
      nil ->
        {:noreply, socket}

      other ->
        {:noreply,
         socket
         |> assign(:other, other)
         |> assign(:keep, default_keep(socket.assigns.album, other))}
    end
  end

  def handle_event("unchoose", _params, socket), do: {:noreply, assign(socket, :other, nil)}

  def handle_event("merge", %{"keep" => keep}, socket) do
    %{album: album, other: other} = socket.assigns
    {target, source} = if keep == other.id, do: {other, album}, else: {album, other}

    case Records.merge_albums(source.id, target.id, actor: socket.assigns.current_user) do
      {:ok, merged} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Albums merged."))
         |> push_navigate(to: ~p"/albums/#{merged}")}

      {:error, %Ash.Error.Forbidden{}} ->
        {:noreply,
         put_flash(
           socket,
           :error,
           gettext(
             "Only those who have one of the two albums in their collection or wishlist can merge them."
           )
         )}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("The albums could not be merged."))}
    end
  end

  # Other albums of the whole catalogue matching the search
  defp search(socket, query) do
    candidates =
      query
      |> String.trim()
      |> then(&if(&1 == "", do: nil, else: &1))
      |> Records.search_albums!(nil, load: @load, actor: socket.assigns.current_user)
      |> Enum.reject(&(&1.id == socket.assigns.album.id))
      |> Enum.take(20)

    socket
    |> assign(:search_form, to_form(%{"q" => query}))
    |> assign(:candidates, candidates)
  end

  # Keep the entry with a cover, otherwise the one with more collectors
  defp default_keep(album, other) do
    cond do
      album.cover_url && !other.cover_url ->
        album.id

      other.cover_url && !album.cover_url ->
        other.id

      length(other.copies) + length(other.wishes) > length(album.copies) + length(album.wishes) ->
        other.id

      true ->
        album.id
    end
  end

  defp holder_text(album) do
    gettext("%{copies}, %{wishes} (all collectors)",
      copies: ngettext("1 copy", "%{count} copies", length(album.copies)),
      wishes: ngettext("1 wish", "%{count} wishes", length(album.wishes))
    )
  end
end
