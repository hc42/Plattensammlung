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

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Album
  alias PlattensammlungWeb.OptionalFields

  @fields [
    year: "Erscheinungsjahr",
    genres: "Genres",
    discogs_master_id: "Discogs-Master-ID"
  ]

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-xl space-y-6">
        <div>
          <.link navigate={@return_to} class="text-sm opacity-70 hover:opacity-100">
            <.icon name="hero-arrow-left-micro" class="size-4" /> Zurück
          </.link>
          <div class="mt-2 flex items-center gap-4">
            <div :if={@album} class="w-20 shrink-0" id="cover-preview">
              <.cover album={@album} class="w-full" />
            </div>
            <div>
              <h1 class="text-2xl font-bold">{@page_title}</h1>
              <p :if={@album} class="text-xs opacity-60">
                Das Cover änderst du auf der <.link navigate={~p"/albums/#{@album}"} class="link">Albumseite</.link>.
              </p>
            </div>
          </div>
          <p :if={@live_action == :new} class="text-sm opacity-70">
            Nur Künstler und Titel sind nötig, alles andere kannst du später ergänzen.
          </p>
        </div>

        <.form for={@form} id="album-form" phx-change="validate" phx-submit="save" class="space-y-2">
          <div :if={@live_action == :new} class="join w-full" id="mode-switch">
            <input
              :for={
                {value, label} <- [
                  {"collection", "In meine Sammlung"},
                  {"wishlist", "Auf die Wunschliste"}
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
            label="Künstler"
            list="artist-names"
            autocomplete="off"
            phx-debounce="300"
            required
          />
          <datalist id="artist-names">
            <option :for={name <- @artist_names} value={name} />
          </datalist>

          <.input field={@form[:title]} label="Titel" phx-debounce="300" required />

          <div
            :if={@duplicates != []}
            id="duplicate-warning"
            class="alert alert-warning alert-soft text-sm"
          >
            <.icon name="hero-exclamation-triangle" class="size-5" />
            <span>
              Dieses Album gibt es schon:
              <.link
                :for={album <- @duplicates}
                navigate={~p"/albums/#{album}"}
                class="link font-medium"
              >
                {if album.owned, do: "in deiner Sammlung", else: "auf der Wunschliste"}
              </.link>
            </span>
          </div>

          <.optional_field
            form={@form}
            field={:year}
            label="Erscheinungsjahr"
            visible={@visible}
            focus={@focus}
          >
            <.input field={@form[:year]} type="number" label="Erscheinungsjahr" min="1900" max="2100" />
          </.optional_field>

          <.optional_field
            form={@form}
            field={:genres}
            label="Genres"
            visible={@visible}
            focus={@focus}
          >
            <div class="fieldset mb-2">
              <span class="label mb-1">Genres</span>
              <%!-- The list goes into the album form; the entry field belongs to #genre-entry --%>
              <input type="hidden" name="album[genres][]" value="" />
              <input :for={genre <- @genres} type="hidden" name="album[genres][]" value={genre} />
              <div class="flex flex-wrap items-center gap-1.5" id="genre-tags">
                <span
                  :for={genre <- @genres}
                  class="badge badge-lg gap-1"
                  id={"genre-#{genre_id(genre)}"}
                >
                  {genre}
                  <button
                    type="button"
                    phx-click="remove_genre"
                    phx-value-genre={genre}
                    class="opacity-60 hover:opacity-100"
                    aria-label={"#{genre} entfernen"}
                  >
                    <.icon name="hero-x-mark-micro" class="size-4" />
                  </button>
                </span>
                <input
                  type="text"
                  id={"genre-input-#{@genre_input_key}"}
                  name="genre"
                  form="genre-entry"
                  list="genre-suggestions"
                  placeholder={if @genres == [], do: "z. B. Rock", else: "weiteres Genre"}
                  autocomplete="off"
                  class="input input-sm w-40"
                  phx-mounted={@genre_input_key > 0 && JS.focus()}
                />
                <button type="submit" form="genre-entry" class="btn btn-ghost btn-sm" id="add-genre">
                  Hinzufügen
                </button>
              </div>
              <datalist id="genre-suggestions">
                <option :for={genre <- @genre_suggestions -- @genres} value={genre} />
              </datalist>
            </div>
          </.optional_field>

          <.optional_field
            form={@form}
            field={:discogs_master_id}
            label="Discogs-Master-ID"
            visible={@visible}
            focus={@focus}
          >
            <.input field={@form[:discogs_master_id]} type="number" label="Discogs-Master-ID" />
          </.optional_field>

          <.input
            :if={@live_action == :edit}
            field={@form[:wanted]}
            type="checkbox"
            label="Auf der Wunschliste"
          />

          <div class="border-t border-base-300 pt-3">
            <.add_field_buttons fields={@fields} visible={@visible} />
          </div>

          <div class="flex gap-2 pt-4">
            <.button variant="primary" phx-disable-with="Speichern…" id="save-album">
              {if @live_action == :new, do: "Hinzufügen", else: "Speichern"}
            </.button>
            <.button navigate={@return_to}>Abbrechen</.button>
          </div>
        </.form>

        <%!-- Own form for the genre entry: Enter adds a tag instead of saving the album --%>
        <form id="genre-entry" phx-submit="add_genre"></form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    artist_names =
      Records.list_artists!(actor: socket.assigns.current_user)
      |> Enum.map(&to_string(&1.name))
      |> Enum.sort()

    {:ok,
     socket
     |> assign(:artist_names, artist_names)
     |> assign(:genre_suggestions, genre_suggestions(socket.assigns.current_user))
     |> assign(:genre_input_key, 0)
     |> assign(:duplicates, [])
     |> assign(:fields, @fields)
     |> assign(:focus, nil)
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    mode = if params["wishlist"], do: "wishlist", else: "collection"

    socket
    |> assign(:page_title, "Platte erfassen")
    |> assign(:album, nil)
    |> assign(:visible, MapSet.new())
    |> assign(:genres, [])
    |> assign(:mode, mode)
    |> assign(:return_to, if(mode == "wishlist", do: ~p"/wishlist", else: ~p"/"))
    |> assign(:form, new_form(mode, socket.assigns.current_user))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    album = Records.get_album!(id, load: [:artist], actor: socket.assigns.current_user)

    form =
      AshPhoenix.Form.for_update(album, :update,
        as: "album",
        actor: socket.assigns.current_user,
        prepare_params: &prepare_params/2,
        params: %{"artist_name" => to_string(album.artist.name)}
      )

    socket
    |> assign(:page_title, "Album bearbeiten")
    |> assign(:album, album)
    |> assign(:visible, OptionalFields.initially_visible(album, @fields))
    |> assign(:genres, album.genres)
    |> assign(:mode, nil)
    |> assign(:return_to, ~p"/albums/#{album}")
    |> assign(:form, to_form(form))
  end

  @impl true
  def handle_event("show_field", %{"field" => field}, socket) do
    {:noreply, OptionalFields.show(socket, field, @fields)}
  end

  def handle_event("hide_field", %{"field" => "genres"}, socket) do
    {:noreply, socket |> assign(:genres, []) |> OptionalFields.hide("genres", @fields)}
  end

  def handle_event("hide_field", %{"field" => field}, socket) do
    {:noreply, OptionalFields.hide(socket, field, @fields)}
  end

  def handle_event("add_genre", %{"genre" => text}, socket) do
    new =
      text
      |> String.split(",")
      |> Enum.map(&normalize_genre(&1, socket.assigns.genre_suggestions))
      |> Enum.reject(&(&1 == ""))

    genres = Enum.uniq_by(socket.assigns.genres ++ new, &String.downcase/1)

    {:noreply,
     socket
     |> update(:genre_input_key, &(&1 + 1))
     |> put_genres(genres)}
  end

  def handle_event("remove_genre", %{"genre" => genre}, socket) do
    {:noreply, put_genres(socket, List.delete(socket.assigns.genres, genre))}
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

    Album
    |> AshPhoenix.Form.for_create(action,
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

  # Keeps the tags and the AshPhoenix form in sync
  defp put_genres(socket, genres) do
    form = socket.assigns.form.source
    params = form |> AshPhoenix.Form.params() |> Map.put("genres", genres)

    socket
    |> assign(:genres, genres)
    |> assign(:form, to_form(AshPhoenix.Form.validate(form, params)))
  end

  # "rock" becomes "Rock" if that genre already exists in the collection
  defp normalize_genre(text, suggestions) do
    text = String.trim(text)
    Enum.find(suggestions, text, &(String.downcase(&1) == String.downcase(text)))
  end

  defp genre_suggestions(actor) do
    Records.search_albums!(nil, nil, actor: actor)
    |> Enum.flat_map(& &1.genres)
    |> Enum.uniq()
    |> Enum.sort()
  end

  defp genre_id(genre), do: genre |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")

  defp find_duplicates(%{"artist_name" => artist, "title" => title}, assigns)
       when artist != "" and title != "" do
    Records.find_duplicates!(artist, title, load: [:owned], actor: assigns.current_user)
    |> Enum.reject(&(assigns.album && &1.id == assigns.album.id))
  end

  defp find_duplicates(_params, _assigns), do: []

  defp saved_message(%{live_action: :edit}, _album), do: "Album gespeichert."

  defp saved_message(%{mode: "wishlist"}, album),
    do: "„#{album.title}“ steht auf der Wunschliste."

  defp saved_message(_assigns, album), do: "„#{album.title}“ ist jetzt in deiner Sammlung."
end
