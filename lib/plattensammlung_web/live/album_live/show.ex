defmodule PlattensammlungWeb.AlbumLive.Show do
  @moduledoc """
  Album details with its copies, wishlist toggle and Discogs links.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.{Accounts, Records}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link navigate={back_path(@album, @owner)} class="text-sm opacity-70 hover:opacity-100">
        <.icon name="hero-arrow-left-micro" class="size-4" />
        {back_label(@album, @owner)}
      </.link>

      <div class="grid gap-8 md:grid-cols-[18rem_1fr]">
        <div class="w-full max-w-72 space-y-2">
          <.cover album={@album} class="w-full" />
          <%!-- Live upload: the image is sent as soon as it is chosen (auto_upload) --%>
          <form :if={!@owner} id="cover-form" phx-change="validate_cover" phx-submit="noop">
            <.live_file_input upload={@uploads.cover} class="hidden" />
            <div class="flex flex-wrap gap-1">
              <label for={@uploads.cover.ref} class="btn btn-ghost btn-sm" id="change-cover">
                <.icon name="hero-photo" class="size-4" />
                {if @album.cover_url, do: "Cover ändern", else: "Cover hinzufügen"}
              </label>
              <button
                :if={@album.cover_url}
                type="button"
                phx-click="remove_cover"
                data-confirm="Cover entfernen?"
                class="btn btn-ghost btn-sm text-error"
                id="remove-cover"
              >
                <.icon name="hero-trash" class="size-4" /> Entfernen
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

          <div :if={@owner} id="ownership" class="space-y-2 rounded-lg bg-base-200 p-4 text-sm">
            <p id="owner-info">
              <.icon name="hero-user-circle" class="size-5 opacity-60" />
              {if @album.owned, do: "Aus der Sammlung", else: "Von der Wunschliste"} von
              <.link navigate={~p"/collectors/#{@owner.id}"} class="link font-medium">
                {Plattensammlung.Accounts.display_name(@owner)}
              </.link>
            </p>
            <%= if @mine do %>
              <.link navigate={~p"/albums/#{@mine}"} class="link" id="my-version">
                {if @mine.owned, do: "Hast du auch", else: "Steht auch auf deiner Wunschliste"}
              </.link>
            <% else %>
              <button
                phx-click="add_to_my_wishlist"
                class="btn btn-sm btn-primary phx-click-loading:pointer-events-none"
                id="add-to-my-wishlist"
              >
                <.loading_icon name="hero-heart" /> Auf meine Wunschliste
              </button>
            <% end %>
          </div>

          <div :if={!@owner} id="ownership" class="rounded-lg bg-base-200 p-4 text-sm">
            <%= cond do %>
              <% @album.owned -> %>
                <.icon name="hero-check-circle" class="size-5 text-success" />
                <span id="owned-status">
                  Hast du – {if @album.copy_count == 1,
                    do: "1 Exemplar",
                    else: "#{@album.copy_count} Exemplare"}
                </span>
              <% @album.wanted -> %>
                <.icon name="hero-heart" class="size-5 text-accent" />
                <span id="owned-status">Steht auf deiner Wunschliste</span>
              <% true -> %>
                <.icon name="hero-minus-circle" class="size-5 opacity-60" />
                <span id="owned-status">Nicht in deiner Sammlung</span>
            <% end %>
          </div>

          <div :if={!@owner} class="flex flex-wrap gap-2" id="album-actions">
            <.button navigate={~p"/albums/#{@album}/copies/new"} variant="primary" id="add-copy">
              <.icon name="hero-plus" class="size-4" />
              {if @album.owned, do: "Weiteres Exemplar", else: "Habe ich jetzt"}
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
              {if @album.wanted, do: "Von Wunschliste entfernen", else: "Auf Wunschliste"}
            </.button>
            <.button navigate={~p"/albums/#{@album}/match"} id="match-album" class="btn btn-ghost">
              <.icon name="hero-arrow-path" class="size-4" /> Abgleichen
            </.button>
            <.button navigate={~p"/albums/#{@album}/edit"} id="edit-album" class="btn btn-ghost">
              <.icon name="hero-pencil-square" class="size-4" /> Bearbeiten
            </.button>
            <.button
              phx-click="delete"
              data-confirm="Album mit allen Exemplaren löschen?"
              id="delete-album"
              class="btn btn-ghost text-error"
            >
              <.icon name="hero-trash" class="size-4" /> Löschen
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
              :if={!@owner and can_find_streaming?(@album)}
              phx-click="find_streaming_links"
              class="btn btn-sm btn-ghost phx-click-loading:pointer-events-none"
              id="find-streaming-links"
            >
              <.loading_icon name="hero-magnifying-glass" /> Streaming-Links suchen
            </button>
            <a
              :if={@album.discogs_url}
              href={@album.discogs_url}
              target="_blank"
              rel="noopener"
              class="link inline-flex items-center gap-1"
              id="discogs-link"
            >
              Auf Discogs ansehen <.icon name="hero-arrow-top-right-on-square-micro" class="size-4" />
            </a>
          </div>
        </div>
      </div>

      <section :if={@album.copies != []} class="space-y-3">
        <h2 class="text-lg font-semibold">Exemplare</h2>
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
              <div :if={!@owner} class="flex gap-1">
                <.link
                  navigate={~p"/copies/#{copy}/edit"}
                  class="btn btn-ghost btn-xs"
                  id={"edit-copy-#{copy.id}"}
                  aria-label="Exemplar bearbeiten"
                >
                  <.icon name="hero-pencil-square" class="size-4" />
                </.link>
                <button
                  phx-click="delete_copy"
                  phx-value-id={copy.id}
                  data-confirm="Exemplar löschen?"
                  class="btn btn-ghost btn-xs text-error"
                  id={"delete-copy-#{copy.id}"}
                  aria-label="Exemplar löschen"
                >
                  <.icon name="hero-trash" class="size-4" />
                </button>
              </div>
            </div>
            <dl class="grid grid-cols-[auto_1fr] gap-x-4 gap-y-1">
              <%= for {label, value} <- copy_details(copy, @owner), value not in [nil, ""] do %>
                <dt class="opacity-60">{label}</dt>
                <dd>{value}</dd>
              <% end %>
            </dl>
            <%!-- Notes stay private to the owner (field policy on Copy) --%>
            <p :if={copy.notes && !@owner} class="mt-2 whitespace-pre-line opacity-80">
              {copy.notes}
            </p>
            <a
              :if={copy.discogs_url}
              href={copy.discogs_url}
              target="_blank"
              rel="noopener"
              class="link mt-2 inline-flex items-center gap-1 text-xs"
            >
              Pressung auf Discogs
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

  # Copies the album data (not the copies) to the own wishlist
  def handle_event("add_to_my_wishlist", _params, socket) do
    case Records.copy_to_wishlist(socket.assigns.album.id,
           actor: socket.assigns.current_user
         ) do
      {:ok, mine} ->
        {:noreply,
         socket
         |> put_flash(:info, "„#{mine.title}“ steht jetzt auf deiner Wunschliste.")
         |> push_navigate(to: ~p"/albums/#{mine}")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Das hat nicht geklappt.")}
    end
  end

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
        do: "Keine Streaming-Links gefunden. Du kannst sie unter „Bearbeiten“ selbst eintragen.",
        else: "Gefunden: #{Enum.join(found, ", ")}."

    {:noreply, socket |> put_flash(:info, message) |> load_album(album.id)}
  end

  def handle_event("remove_cover", _params, socket) do
    album = Records.remove_cover!(socket.assigns.album, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, "Cover entfernt.")
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

  def handle_event("delete", _params, socket) do
    album = socket.assigns.album
    Records.destroy_album!(album, actor: socket.assigns.current_user)

    {:noreply,
     socket
     |> put_flash(:info, "„#{album.title}“ wurde gelöscht.")
     |> push_navigate(to: back_path(album, nil))}
  end

  def handle_event("delete_copy", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    id |> Records.get_copy!(actor: actor) |> Records.destroy_copy!(actor: actor)

    {:noreply,
     socket
     |> put_flash(:info, "Exemplar gelöscht.")
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
          {:noreply, socket |> put_flash(:info, "Cover gespeichert.") |> load_album(album.id)}

        {:error, _error} ->
          {:noreply, put_flash(socket, :error, "Das Bild konnte nicht gelesen werden.")}
      end
    else
      {:noreply, socket}
    end
  end

  defp cover_errors(upload) do
    (upload_errors(upload) ++ Enum.flat_map(upload.entries, &upload_errors(upload, &1)))
    |> Enum.map(fn
      :too_large -> "Das Bild ist größer als 10 MB."
      :not_accepted -> "Bitte ein Bild im Format JPEG, PNG, WebP oder GIF wählen."
      :too_many_files -> "Bitte nur ein Bild wählen."
      _other -> "Das Bild konnte nicht hochgeladen werden."
    end)
    |> Enum.uniq()
  end

  defp load_album(socket, id) do
    album =
      Records.get_album!(id,
        actor: socket.assigns.current_user,
        load: [
          :artist,
          :owned,
          :copy_count,
          :discogs_url,
          :spotify_url,
          :tidal_url,
          copies: [:discogs_url]
        ]
      )

    actor = socket.assigns.current_user

    # Someone else's album: show whose it is and whether I have it too
    {owner, mine} =
      if album.owner_id == actor.id do
        {nil, nil}
      else
        {Accounts.get_collector!(album.owner_id, actor: actor),
         album.artist.name
         |> Records.find_duplicates!(album.title, load: [:owned], actor: actor)
         |> List.first()}
      end

    socket
    |> assign(:album, album)
    |> assign(:owner, owner)
    |> assign(:mine, mine)
    |> assign(:page_title, "#{album.artist.name} – #{album.title}")
  end

  # Wikidata needs a Discogs or MusicBrainz link to find the album
  defp can_find_streaming?(album) do
    (is_nil(album.spotify_album_id) or is_nil(album.tidal_album_id)) and
      not is_nil(album.discogs_master_id || album.musicbrainz_release_group_id)
  end

  defp back_path(%{owned: true}, nil), do: ~p"/"
  defp back_path(%{wanted: true}, nil), do: ~p"/wishlist"
  defp back_path(_album, nil), do: ~p"/albums"
  defp back_path(%{owned: true}, owner), do: ~p"/collectors/#{owner.id}"
  defp back_path(_album, owner), do: ~p"/collectors/#{owner.id}/wishlist"

  defp back_label(%{owned: true}, nil), do: "Sammlung"
  defp back_label(%{wanted: true}, nil), do: "Wunschliste"
  defp back_label(_album, nil), do: "Alle Alben"
  defp back_label(_album, owner), do: Accounts.display_name(owner)

  defp copy_heading(copy) do
    [
      Enum.join(copy.format, ", "),
      copy.label,
      copy.pressing_year && to_string(copy.pressing_year)
    ]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> "Exemplar"
      parts -> Enum.join(parts, " · ")
    end
  end

  # Purchase date stays private to the owner; for others the field policy on
  # Copy returns %Ash.ForbiddenField{} anyway
  defp purchase_date(%{purchased_on: %Date{} = date}, nil),
    do: Calendar.strftime(date, "%d.%m.%Y")

  defp purchase_date(_copy, _owner), do: nil

  defp copy_details(copy, owner) do
    [
      {"Katalognummer", copy.catalog_number},
      {"Barcode", copy.barcode},
      {"Land", copy.country},
      {"Zustand Platte", condition_label(copy.media_condition)},
      {"Zustand Hülle", condition_label(copy.sleeve_condition)},
      {"Gekauft am", purchase_date(copy, owner)}
    ]
  end
end
