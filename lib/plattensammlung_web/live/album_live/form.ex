defmodule PlattensammlungWeb.AlbumLive.Form do
  @moduledoc """
  Quick capture of a new album (collection or wishlist) and editing of an
  existing one. Forms are built with `AshPhoenix.Form`, which runs the Ash
  action's validations on every change.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Album

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-xl space-y-6">
        <div>
          <.link navigate={@return_to} class="text-sm opacity-70 hover:opacity-100">
            <.icon name="hero-arrow-left-micro" class="size-4" /> Zurück
          </.link>
          <h1 class="mt-2 text-2xl font-bold">{@page_title}</h1>
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

          <.input field={@form[:year]} type="number" label="Erscheinungsjahr" min="1900" max="2100" />

          <details
            class="group rounded-lg border border-base-300 px-4 py-2"
            open={@live_action == :edit}
          >
            <summary class="cursor-pointer text-sm font-medium opacity-80">Weitere Angaben</summary>
            <div class="pt-2">
              <.input
                field={@form[:cover_url]}
                type="url"
                label="Cover-URL"
                placeholder="https://…"
              />
              <.input
                field={@form[:genres]}
                value={genres_value(@form[:genres].value)}
                label="Genres (durch Komma getrennt)"
                placeholder="Rock, Jazz"
              />
              <.input field={@form[:discogs_master_id]} type="number" label="Discogs-Master-ID" />
              <.input
                :if={@live_action == :edit}
                field={@form[:wanted]}
                type="checkbox"
                label="Auf der Wunschliste"
              />
            </div>
          </details>

          <div class="flex gap-2 pt-4">
            <.button variant="primary" phx-disable-with="Speichern…" id="save-album">
              {if @live_action == :new, do: "Hinzufügen", else: "Speichern"}
            </.button>
            <.button navigate={@return_to}>Abbrechen</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    artist_names = Records.list_artists!() |> Enum.map(&to_string(&1.name)) |> Enum.sort()

    {:ok,
     socket
     |> assign(:artist_names, artist_names)
     |> assign(:duplicates, [])
     |> apply_action(socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, params) do
    mode = if params["wishlist"], do: "wishlist", else: "collection"

    socket
    |> assign(:page_title, "Platte erfassen")
    |> assign(:album, nil)
    |> assign(:mode, mode)
    |> assign(:return_to, if(mode == "wishlist", do: ~p"/wishlist", else: ~p"/"))
    |> assign(:form, new_form(mode))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    album = Records.get_album!(id, load: [:artist])

    form =
      AshPhoenix.Form.for_update(album, :update,
        as: "album",
        prepare_params: &prepare_params/2,
        params: %{"artist_name" => to_string(album.artist.name)}
      )

    socket
    |> assign(:page_title, "Album bearbeiten")
    |> assign(:album, album)
    |> assign(:mode, nil)
    |> assign(:return_to, ~p"/albums/#{album}")
    |> assign(:form, to_form(form))
  end

  @impl true
  def handle_event("validate", %{"album" => params} = all_params, socket) do
    socket =
      case all_params["mode"] do
        mode when mode in ["collection", "wishlist"] and mode != socket.assigns.mode ->
          socket |> assign(:mode, mode) |> assign(:form, new_form(mode))

        _ ->
          socket
      end

    form = AshPhoenix.Form.validate(socket.assigns.form, params)

    {:noreply,
     socket
     |> assign(:form, form)
     |> assign(:duplicates, find_duplicates(params, socket.assigns.album))}
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

  defp new_form(mode) do
    action = if mode == "wishlist", do: :add_to_wishlist, else: :add_to_collection

    Album
    |> AshPhoenix.Form.for_create(action, as: "album", prepare_params: &prepare_params/2)
    |> to_form()
  end

  # The genres field is a comma separated text input, the action expects a list
  defp prepare_params(%{"genres" => genres} = params, _type) when is_binary(genres) do
    list = genres |> String.split(",") |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == ""))
    Map.put(params, "genres", list)
  end

  defp prepare_params(params, _type), do: params

  defp genres_value(genres) when is_list(genres), do: Enum.join(genres, ", ")
  defp genres_value(genres), do: genres

  defp find_duplicates(%{"artist_name" => artist, "title" => title}, current)
       when artist != "" and title != "" do
    Records.find_duplicates!(artist, title, load: [:owned])
    |> Enum.reject(&(current && &1.id == current.id))
  end

  defp find_duplicates(_params, _current), do: []

  defp saved_message(%{live_action: :edit}, _album), do: "Album gespeichert."

  defp saved_message(%{mode: "wishlist"}, album),
    do: "„#{album.title}“ steht auf der Wunschliste."

  defp saved_message(_assigns, album), do: "„#{album.title}“ ist jetzt in deiner Sammlung."
end
