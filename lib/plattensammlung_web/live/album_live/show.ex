defmodule PlattensammlungWeb.AlbumLive.Show do
  @moduledoc """
  Album details: the actor's copies and wishlist status, who else has the album,
  and links. Albums are shared (ADR 0016): everyone who has it in collection or
  wishlist may change the album data; copies only their owner.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.{Accounts, Records}
  alias PlattensammlungWeb.Ownership

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link navigate={back_path(@album)} class="text-sm opacity-70 hover:opacity-100">
        <.icon name="hero-arrow-left-micro" class="size-4" />
        {back_label(@album)}
      </.link>

      <div class="grid gap-8 md:grid-cols-[18rem_1fr]">
        <div class="w-full max-w-72 space-y-2">
          <.cover album={@album} class="w-full" />
          <%!-- Live upload: the image is sent as soon as it is chosen (auto_upload) --%>
          <form :if={@can_edit} id="cover-form" phx-change="validate_cover" phx-submit="noop">
            <.live_file_input upload={@uploads.cover} class="hidden" />
            <div class="flex flex-wrap gap-1">
              <label for={@uploads.cover.ref} class="btn btn-ghost btn-sm" id="change-cover">
                <.icon name="hero-photo" class="size-4" />
                {if @album.cover_url, do: gettext("Change cover"), else: gettext("Add cover")}
              </label>
              <button
                :if={@album.cover_url}
                type="button"
                phx-click="remove_cover"
                data-confirm={gettext("Remove cover?")}
                class="btn btn-ghost btn-sm text-error"
                id="remove-cover"
              >
                <.icon name="hero-trash" class="size-4" /> {gettext("Remove")}
              </button>
            </div>
            <progress
              :for={entry <- @uploads.cover.entries}
              value={entry.progress}
              max="100"
              class="progress progress-primary w-full"
            />
            <p
              :for={error <- cover_errors(@uploads.cover)}
              class="text-sm text-error"
              id="cover-error"
            >
              {error}
            </p>
          </form>
        </div>

        <div class="space-y-4">
          <div>
            <p class="text-lg opacity-80">{@album.artist.name}</p>
            <h1 class="text-3xl font-bold leading-tight">{@album.title}</h1>
            <div class="mt-2 flex flex-wrap items-center gap-2 text-sm">
              <span :if={@album.year} class="opacity-70">{@album.year}</span>
              <span :for={genre <- @album.genres} class="badge badge-ghost badge-sm">{genre}</span>
              <.status_badge album={@album} />
            </div>
          </div>

          <div id="ownership" class="space-y-2 rounded-lg bg-base-200 p-4 text-sm">
            <p>
              <%= cond do %>
                <% @album.owned -> %>
                  <.icon name="hero-check-circle" class="size-5 text-success" />
                  <span id="owned-status">
                    {gettext("You have it – %{copies}",
                      copies: ngettext("1 copy", "%{count} copies", @album.copy_count)
                    )}
                  </span>
                <% @album.wanted -> %>
                  <.icon name="hero-heart" class="size-5 text-accent" />
                  <span id="owned-status">{gettext("On your wishlist")}</span>
                <% true -> %>
                  <.icon name="hero-minus-circle" class="size-5 opacity-60" />
                  <span id="owned-status">{gettext("Not in your collection")}</span>
              <% end %>
            </p>
            <p :if={@holders != []} id="other-holders">
              <.icon name="hero-user-group" class="size-5 opacity-60" /> {gettext("Also with")}
              <span :for={{holder, index} <- Enum.with_index(@holders)}>
                <.link
                  navigate={holder_path(holder)}
                  class="link font-medium"
                  id={"holder-#{holder.id}"}
                >
                  {holder.name}
                </.link>
                <span class="opacity-70">({holder_label(holder)})</span>{comma(@holders, index)}
              </span>
            </p>
          </div>

          <div class="flex flex-wrap gap-2" id="album-actions">
            <.button navigate={~p"/albums/#{@album}/copies/new"} variant="primary" id="add-copy">
              <.icon name="hero-plus" class="size-4" />
              {if @album.owned, do: gettext("Another copy"), else: gettext("I have it now")}
            </.button>
            <.button
              :if={!@album.owned}
              phx-click="toggle_wanted"
              id="toggle-wanted"
              class="btn btn-ghost"
            >
              <.icon
                name={if @album.wanted, do: "hero-heart-solid", else: "hero-heart"}
                class="size-4"
              />
              {if @album.wanted, do: gettext("Remove from wishlist"), else: gettext("Add to wishlist")}
            </.button>
            <%= if @can_edit do %>
              <.button
                navigate={~p"/albums/#{@album}/match"}
                id="match-album"
                class="btn btn-ghost"
              >
                <.icon name="hero-arrow-path" class="size-4" /> {gettext("Match")}
              </.button>
              <.button navigate={~p"/albums/#{@album}/edit"} id="edit-album" class="btn btn-ghost">
                <.icon name="hero-pencil-square" class="size-4" /> {gettext("Edit")}
              </.button>
            <% end %>
            <%!-- An album no one has (e.g. after deleting the last copy) can go entirely --%>
            <.button
              :if={@can_edit or @holders == []}
              phx-click="remove"
              data-confirm={remove_confirmation(@holders)}
              id="remove-album"
              class="btn btn-ghost text-error"
            >
              <.icon name="hero-trash" class="size-4" /> {gettext("Remove")}
            </.button>
          </div>

          <div class="flex flex-wrap items-center gap-2 text-sm" id="external-links">
            <a
              :if={@album.spotify_url}
              href={@album.spotify_url}
              target="_blank"
              rel="noopener"
              class="btn btn-sm btn-outline"
              id="spotify-link"
            >
              <.icon name="hero-play-circle" class="size-4" /> Spotify
            </a>
            <a
              :if={@album.tidal_url}
              href={@album.tidal_url}
              target="_blank"
              rel="noopener"
              class="btn btn-sm btn-outline"
              id="tidal-link"
            >
              <.icon name="hero-play-circle" class="size-4" /> Tidal
            </a>
            <button
              :if={@can_edit and can_find_streaming?(@album)}
              phx-click="find_streaming_links"
              class="btn btn-sm btn-ghost phx-click-loading:pointer-events-none"
              id="find-streaming-links"
            >
              <.loading_icon name="hero-magnifying-glass" /> {gettext("Find streaming links")}
            </button>
            <a
              :if={@album.discogs_url}
              href={@album.discogs_url}
              target="_blank"
              rel="noopener"
              class="link inline-flex items-center gap-1"
              id="discogs-link"
            >
              {gettext("View on Discogs")}
              <.icon name="hero-arrow-top-right-on-square-micro" class="size-4" />
            </a>
          </div>
        </div>
      </div>

      <section :if={@album.copies != []} class="space-y-3">
        <h2 class="text-lg font-semibold">{gettext("Your copies")}</h2>
        <div id="copies" class="grid gap-3 sm:grid-cols-2">
          <div
            :for={copy <- @album.copies}
            id={"copy-#{copy.id}"}
            class="rounded-lg border border-base-300 p-4 text-sm"
          >
            <div class="mb-2 flex items-start justify-between gap-2">
              <p class="font-medium">
                {copy_heading(copy)}
              </p>
              <div class="flex gap-1">
                <.link
                  navigate={~p"/copies/#{copy}/edit"}
                  class="btn btn-ghost btn-xs"
                  id={"edit-copy-#{copy.id}"}
                  aria-label={gettext("Edit copy")}
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                </.link>
                <button
                  phx-click="delete_copy"
                  phx-value-id={copy.id}
                  data-confirm={gettext("Delete copy?")}
                  class="btn btn-ghost btn-xs text-error"
                  id={"delete-copy-#{copy.id}"}
                  aria-label={gettext("Delete copy")}
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </div>
            </div>
            <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
              <%= for {label, value} <- copy_details(copy), value not in [nil, ""] do %>
                <dt class="opacity-60">{label}</dt>
                <dd>{value}</dd>
              <% end %>
            </dl>
            <p :if={copy.notes} class="mt-2 whitespace-pre-line opacity-80">
              {copy.notes}
            </p>
            <a
              :if={copy.discogs_url}
              href={copy.discogs_url}
              target="_blank"
              rel="noopener"
              class="link mt-2 inline-flex items-center gap-1 text-xs"
            >
              {gettext("Pressing on Discogs")}
              <.icon name="hero-arrow-top-right-on-square-micro" class="size-3" />
            </a>
          </div>
        </div>
      </section>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok,
     socket
     |> allow_upload(:cover,
       accept: ~w(.jpg .jpeg .png .webp .gif),
       max_entries: 1,
       max_file_size: 10_000_000,
       auto_upload: true,
       progress: &handle_cover_progress/3
     )
     |> load_album(id)}
  end

  @impl true
  def handle_event("validate_cover", _params, socket), do: {:noreply, socket}
  def handle_event("noop", _params, socket), do: {:noreply, socket}

  def handle_event("find_streaming_links", _params, socket) do
    before = socket.assigns.album
    album = Records.find_streaming_links!(before, actor: socket.assigns.current_user)

    found =
      [
        (is_nil(before.spotify_album_id) and album.spotify_album_id) && "Spotify",
        (is_nil(before.tidal_album_id) and album.tidal_album_id) && "Tidal"
      ]
      |> Enum.filter(& &1)

    message =
      if found == [],
        do: gettext("No streaming links found. You can add them yourself under “Edit”."),
        else: gettext("Found: %{links}.", links: Enum.join(found, ", "))

    {:noreply, socket |> put_flash(:info, message) |> load_album(album.id)}
  end

  def handle_event("remove_cover", _params, socket) do
    album = Records.remove_cover!(socket.assigns.album, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Cover removed."))
     |> load_album(album.id)}
  end

  def handle_event("toggle_wanted", _params, socket) do
    album = socket.assigns.album

    if album.wanted do
      Records.unmark_wanted!(album, actor: socket.assigns.current_user)
    else
      Records.mark_wanted!(album, actor: socket.assigns.current_user)
    end

    {:noreply, load_album(socket, album.id)}
  end

  # Own copies and wish go; the album stays for the others (ADR 0016)
  def handle_event("remove", _params, socket) do
    album = socket.assigns.album
    Records.remove_album!(album.id, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, gettext("“%{title}” was removed.", title: album.title))
     |> push_navigate(to: back_path(album))}
  end

  def handle_event("delete_copy", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    id |> Records.get_copy!(actor: actor) |> Records.destroy_copy!(actor: actor)

    {:noreply,
     socket
     |> put_flash(:info, gettext("Copy deleted."))
     |> load_album(socket.assigns.album.id)}
  end

  defp handle_cover_progress(:cover, entry, socket) do
    if entry.done? do
      album = socket.assigns.album
      actor = socket.assigns.current_user

      result =
        consume_uploaded_entry(socket, entry, fn %{path: path} ->
          # The temporary upload file is removed after this function returns
          {:ok, Records.upload_cover(album, Ash.Type.File.from_path(path), actor: actor)}
        end)

      case result do
        {:ok, _album} ->
          {:noreply, socket |> put_flash(:info, gettext("Cover saved.")) |> load_album(album.id)}

        {:error, _error} ->
          {:noreply, put_flash(socket, :error, gettext("The image could not be read."))}
      end
    else
      {:noreply, socket}
    end
  end

  defp cover_errors(upload) do
    (upload_errors(upload) ++ Enum.flat_map(upload.entries, &upload_errors(upload, &1)))
    |> Enum.map(fn
      :too_large -> gettext("The image is larger than 10 MB.")
      :not_accepted -> gettext("Please choose a JPEG, PNG, WebP or GIF image.")
      :too_many_files -> gettext("Please choose only one image.")
      _other -> gettext("The image could not be uploaded.")
    end)
    |> Enum.uniq()
  end

  defp load_album(socket, id) do
    actor = socket.assigns.current_user

    album =
      Records.get_album!(id,
        actor: actor,
        load: [
          :artist,
          :owned,
          :wanted,
          :copy_count,
          :discogs_url,
          :spotify_url,
          :tidal_url,
          copies: Ash.Query.load(Ownership.own_copies(actor), :discogs_url)
        ]
      )

    socket
    |> assign(:album, album)
    |> assign(:can_edit, album.owned or album.wanted)
    |> assign(:holders, holders(album.id, actor))
    |> assign(:page_title, "#{album.artist.name} – #{album.title}")
  end

  # Other users who have the album: name, number of copies, wish
  defp holders(album_id, actor) do
    %{copies: copies, wishes: wishes} =
      Records.get_album!(album_id, load: [:copies, :wishes], actor: actor)

    copy_counts = copies |> Enum.map(& &1.owner_id) |> Enum.frequencies()
    wishers = MapSet.new(wishes, & &1.owner_id)

    Accounts.list_collectors!(actor: actor)
    |> Enum.reject(&(&1.id == actor.id))
    |> Enum.filter(&(Map.has_key?(copy_counts, &1.id) or MapSet.member?(wishers, &1.id)))
    |> Enum.map(fn user ->
      %{
        id: user.id,
        name: user_name(user),
        copies: Map.get(copy_counts, user.id, 0),
        wanted: MapSet.member?(wishers, user.id)
      }
    end)
  end

  defp holder_path(%{copies: 0} = holder), do: ~p"/collectors/#{holder.id}/wishlist"
  defp holder_path(holder), do: ~p"/collectors/#{holder.id}"

  # Between holders, directly after the previous one (no space before it)
  defp comma(holders, index), do: if(index < length(holders) - 1, do: ",")

  defp holder_label(%{copies: 0}), do: gettext("Wishlist")
  defp holder_label(%{copies: count}), do: ngettext("1 copy", "%{count} copies", count)

  defp remove_confirmation([]),
    do: gettext("Delete the album? No one else has it in their collection or wishlist.")

  defp remove_confirmation(_holders),
    do: gettext("Remove your copies and your wish? The others keep the album.")

  # Wikidata needs a Discogs or MusicBrainz link to find the album
  defp can_find_streaming?(album) do
    (is_nil(album.spotify_album_id) or is_nil(album.tidal_album_id)) and
      not is_nil(album.discogs_master_id || album.musicbrainz_release_group_id)
  end

  defp back_path(%{owned: true}), do: ~p"/"
  defp back_path(%{wanted: true}), do: ~p"/wishlist"
  defp back_path(_album), do: ~p"/albums"

  defp back_label(%{owned: true}), do: gettext("Collection")
  defp back_label(%{wanted: true}), do: gettext("Wishlist")
  defp back_label(_album), do: gettext("All albums")

  defp copy_heading(copy) do
    [
      Enum.join(copy.format, ", "),
      copy.label,
      copy.pressing_year && to_string(copy.pressing_year)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> gettext("Copy")
      parts -> Enum.join(parts, " · ")
    end
  end

  defp purchase_date(%{purchased_on: %Date{} = date}), do: format_date(date)
  defp purchase_date(_copy), do: nil

  defp copy_details(copy) do
    [
      {field_label(:catalog_number), copy.catalog_number},
      {field_label(:barcode), copy.barcode},
      {field_label(:country), copy.country},
      {gettext("Media condition"), condition_label(copy.media_condition)},
      {gettext("Sleeve condition"), condition_label(copy.sleeve_condition)},
      {gettext("Purchased on"), purchase_date(copy)}
    ]
  end
end
