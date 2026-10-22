defmodule PlattensammlungWeb.AlbumLive.Form do
  @moduledoc """
  Quick capture of a new album (collection or wishlist) and editing of an
  existing one. Forms are built with `AshPhoenix.Form`, which runs the Ash
  action's validations on every change.

  Only artist and title are always shown; year, genres and the Discogs id are
  optional fields behind "+" (`PlattensammlungWeb.OptionalFields`). Genres are
  edited as tags. The cover is only previewed here; it is changed on the album
  page (upload) or via matching.
  """
  use PlattensammlungWeb, :live_view

  import PlattensammlungWeb.OptionalFields
  import PlattensammlungWeb.TagInput

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Album
  alias PlattensammlungWeb.{OptionalFields, TagInput}

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user} current_path={@current_path}>
      <div class="mx-auto max-w-xl space-y-6">
        <div>
          <.back_link navigate={@return_to}>{gettext("Back")}</.back_link>
          <div class="mt-3 flex items-center gap-4">
            <div :if={@album} class="w-20 shrink-0" id="cover-preview">
              <.cover album={@album} class="w-full" />
            </div>
            <div>
              <h1 class="text-2xl font-bold">{@page_title}</h1>
              <p :if={@album} class="text-xs opacity-60">
                {gettext("You change the cover on the")}
                <.link navigate={~p"/albums/#{@album}"} class="link">{gettext("album page")}</.link>.
              </p>
            </div>
          </div>
          <p :if={@live_action == :new} class="text-sm opacity-70">
            {gettext("Only artist and title are needed, you can add everything else later.")}
          </p>
        </div>

        <.form for={@form} id="album-form" phx-change="validate" phx-submit="save" class="space-y-2">
          <div :if={@live_action == :new} class="join w-full" id="mode-switch">
            <input
              :for={
                {value, label} <- [
                  {"collection", gettext("To my collection")},
                  {"wishlist", gettext("To the wishlist")}
                ]
              }
              type="radio"
              name="mode"
              value={value}
              id={"mode-#{value}"}
              aria-label={label}
              checked={@mode == value}
              class="join-item btn btn-sm flex-1"
            />
          </div>

          <.input
            field={@form[:artist_name]}
            label={gettext("Artist")}
            list="artist-names"
            autocomplete="off"
            maxlength="200"
            phx-debounce="300"
            required
          />
          <datalist id="artist-names">
            <option :for={name <- @artist_names} value={name} />
          </datalist>

          <.input
            field={@form[:title]}
            label={gettext("Title")}
            maxlength="200"
            phx-debounce="300"
            required
          />

          <div
            :if={@duplicates != []}
            id="duplicate-warning"
            class="alert alert-warning alert-soft text-sm"
          >
            <.icon name="hero-exclamation-triangle" class="size-5" />
            <span>
              {gettext("This album already exists")}
              <.link
                :for={album <- @duplicates}
                navigate={~p"/albums/#{album}"}
                class="link font-medium"
              >
                {duplicate_label(album)}
              </.link>
            </span>
          </div>

          <.optional_field
            form={@form}
            field={:year}
            label={gettext("Release year")}
            visible={@visible}
            focus={@focus}
          >
            <.input
              field={@form[:year]}
              type="number"
              label={gettext("Release year")}
              min="1900"
              max="2100"
            />
          </.optional_field>

          <.optional_field
            form={@form}
            field={:genres}
            label={gettext("Genres")}
            visible={@visible}
            focus={@focus}
          >
            <.tag_input
              form_name="album"
              field={:genres}
              label={gettext("Genres")}
              tags={@tags}
              keys={@tag_keys}
              suggestions={@genre_suggestions}
              placeholder={gettext("e.g. Rock")}
            />
          </.optional_field>

          <.optional_field
            form={@form}
            field={:spotify_album_id}
            label="Spotify"
            visible={@visible}
            focus={@focus}
          >
            <.input
              field={@form[:spotify_album_id]}
              label={gettext("Spotify (link or ID)")}
              maxlength="200"
              placeholder="https://open.spotify.com/album/…"
            />
          </.optional_field>

          <.optional_field
            form={@form}
            field={:tidal_album_id}
            label="Tidal"
            visible={@visible}
            focus={@focus}
          >
            <.input
              field={@form[:tidal_album_id]}
              label={gettext("Tidal (link or ID)")}
              maxlength="200"
              placeholder="https://tidal.com/album/…"
            />
          </.optional_field>

          <.optional_field
            form={@form}
            field={:discogs_master_id}
            label={gettext("Discogs master ID")}
            visible={@visible}
            focus={@focus}
          >
            <%!-- An id, not a quantity: no number spinner, but a digit keypad on phones --%>
            <.input
              field={@form[:discogs_master_id]}
              type="text"
              inputmode="numeric"
              autocomplete="off"
              maxlength="12"
              label={gettext("Discogs master ID")}
            />
          </.optional_field>

          <.input
            :if={@live_action == :edit}
            field={@form[:wanted]}
            type="checkbox"
            label={gettext("On the wishlist")}
          />

          <div class="border-t border-base-300 pt-3">
            <.add_field_buttons fields={@fields} visible={@visible} />
          </div>

          <div class="flex gap-2 pt-4">
            <.button variant="primary" phx-disable-with={gettext("Saving …")} id="save-album">
              {if @live_action == :new, do: gettext("Add"), else: gettext("Save")}
            </.button>
            <.button navigate={@return_to}>{gettext("Cancel")}</.button>
          </div>
        </.form>

        <.tag_entry_forms fields={[:genres]} />
      </div>
    </Layouts.app>
    """
  end

  # Optional fields with their labels (a function: the labels depend on the language)
  defp fields do
    [
      year: gettext("Release year"),
      genres: gettext("Genres"),
      spotify_album_id: "Spotify",
      tidal_album_id: "Tidal",
      discogs_master_id: gettext("Discogs master ID")
    ]
  end

  @impl true
  def mount(params, _session, socket) do
    artist_names =
      Records.list_artists!(actor: socket.assigns.current_user)
      |> Enum.map(&to_string(&1.name))
      |> Enum.sort()

    socket =
      socket
      |> assign(:artist_names, artist_names)
      |> assign(:genre_suggestions, genre_suggestions(socket.assigns.current_user))
      |> assign(:tag_keys, %{})
      |> assign(:duplicates, [])
      |> assign(:fields, fields())
      |> assign(:focus, nil)
      |> apply_action(socket.assigns.live_action, params)

    case socket.assigns[:album] do
      nil ->
        {:ok, socket}

      album ->
        case PlattensammlungWeb.Ownership.require_editable(socket, album) do
          :ok -> {:ok, socket}
          {:redirect, socket} -> {:ok, socket}
        end
    end
  end

  defp apply_action(socket, :new, params) do
    mode = if params["wishlist"], do: "wishlist", else: "collection"

    socket
    |> assign(:page_title, gettext("Add a record"))
    |> assign(:album, nil)
    |> assign(:visible, MapSet.new())
    |> assign(:tags, %{genres: []})
    |> assign(:mode, mode)
    |> assign(:return_to, if(mode == "wishlist", do: ~p"/wishlist", else: ~p"/"))
    |> assign(:form, new_form(mode, socket.assigns.current_user))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    album =
      Records.get_album!(id,
        load: [:artist, :owned, :wanted, :editable],
        actor: socket.assigns.current_user
      )

    form =
      AshPhoenix.Form.for_update(album, :update,
        as: "album",
        actor: socket.assigns.current_user,
        prepare_params: &prepare_params/2,
        params: %{"artist_name" => to_string(album.artist.name), "wanted" => album.wanted}
      )

    socket
    |> assign(:page_title, gettext("Edit album"))
    |> assign(:album, album)
    |> assign(:visible, OptionalFields.initially_visible(album, fields()))
    |> assign(:tags, %{genres: album.genres})
    |> assign(:mode, nil)
    |> assign(:return_to, ~p"/albums/#{album}")
    |> assign(:form, to_form(form))
  end

  @impl true
  def handle_event("show_field", %{"field" => field}, socket) do
    {:noreply, OptionalFields.show(socket, field, fields())}
  end

  def handle_event("hide_field", %{"field" => "genres"}, socket) do
    {:noreply, socket |> TagInput.clear(:genres) |> OptionalFields.hide("genres", fields())}
  end

  def handle_event("hide_field", %{"field" => field}, socket) do
    {:noreply, OptionalFields.hide(socket, field, fields())}
  end

  def handle_event("add_tag", %{"field" => field, "tag" => text}, socket) do
    {:noreply, TagInput.add(socket, field, text, tag_config(socket))}
  end

  def handle_event("remove_tag", %{"field" => field, "tag" => tag}, socket) do
    {:noreply, TagInput.remove(socket, field, tag, tag_config(socket))}
  end

  def handle_event("validate", %{"album" => params} = all_params, socket) do
    socket =
      case all_params["mode"] do
        mode when mode in ["collection", "wishlist"] and mode != socket.assigns.mode ->
          socket
          |> assign(:mode, mode)
          |> assign(:form, new_form(mode, socket.assigns.current_user))

        _ ->
          socket
      end

    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:duplicates, find_duplicates(params, socket.assigns))}
  end

  def handle_event("save", %{"album" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, album} ->
        {:noreply,
         socket
         |> put_flash(:info, saved_message(socket.assigns, album))
         |> push_navigate(to: ~p"/albums/#{album}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end

  defp new_form(mode, actor) do
    action = if mode == "wishlist", do: :add_to_wishlist, else: :add_to_collection

    # Generic actions (they reuse an album already in the catalog), so for_action
    Album
    |> AshPhoenix.Form.for_action(action,
      as: "album",
      actor: actor,
      prepare_params: &prepare_params/2
    )
    |> to_form()
  end

  # Genres arrive as album[genres][] (tags, plus an empty marker) or as a single
  # empty value when the field is hidden; the action expects a clean list
  defp prepare_params(%{"genres" => genres} = params, _type) when is_list(genres) do
    Map.put(params, "genres", genres |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")))
  end

  defp prepare_params(%{"genres" => ""} = params, _type), do: Map.put(params, "genres", [])
  defp prepare_params(params, _type), do: params

  defp tag_config(socket) do
    %{genres: %{multiple: true, suggestions: socket.assigns.genre_suggestions}}
  end

  defp genre_suggestions(actor) do
    Records.search_albums!(nil, nil, actor: actor)
    |> Enum.flat_map(& &1.genres)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp find_duplicates(%{"artist_name" => artist, "title" => title}, assigns)
       when artist != "" and title != "" do
    Records.find_duplicates!(artist, title, load: [:owned, :wanted], actor: assigns.current_user)
    |> Enum.reject(&(assigns.album && &1.id == assigns.album.id))
  end

  defp find_duplicates(_params, _assigns), do: []

  defp duplicate_label(%{owned: true}), do: gettext("in your collection.")
  defp duplicate_label(%{wanted: true}), do: gettext("on your wishlist.")
  defp duplicate_label(_album), do: gettext("with other collectors; it will be reused.")

  defp saved_message(%{live_action: :edit}, _album), do: gettext("Album saved.")

  defp saved_message(%{mode: "wishlist"}, album),
    do: gettext("“%{title}” is on the wishlist.", title: album.title)

  defp saved_message(_assigns, album),
    do: gettext("“%{title}” is now in your collection.", title: album.title)
end
