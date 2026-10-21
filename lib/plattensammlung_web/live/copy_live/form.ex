defmodule PlattensammlungWeb.CopyLive.Form do
  @moduledoc """
  Adds or edits a copy of an album. Every field is optional.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Copy

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-xl space-y-6">
        <div>
          <.link navigate={~p"/albums/#{@album}"} class="text-sm opacity-70 hover:opacity-100">
            <.icon name="hero-arrow-left-micro" class="size-4" /> {@album.title}
          </.link>
          <h1 class="mt-2 text-2xl font-bold">{@page_title}</h1>
          <p class="text-sm opacity-70">
            {@album.artist.name} – {@album.title}. Alle Angaben sind optional.
          </p>
        </div>

        <.form for={@form} id="copy-form" phx-change="validate" phx-submit="save">
          <div class="grid gap-x-4 sm:grid-cols-2">
            <.input field={@form[:format]} label="Format" placeholder="LP, 2LP, 7″ …" />
            <.input field={@form[:label]} label="Label" />
            <.input field={@form[:catalog_number]} label="Katalognummer" />
            <.input field={@form[:barcode]} label="Barcode" inputmode="numeric" />
            <.input field={@form[:country]} label="Land" />
            <.input field={@form[:pressing_year]} type="number" label="Jahr der Pressung" />
            <.input
              field={@form[:media_condition]}
              type="select"
              label="Zustand Platte"
              prompt="–"
              options={condition_options()}
            />
            <.input
              field={@form[:sleeve_condition]}
              type="select"
              label="Zustand Hülle"
              prompt="–"
              options={condition_options()}
            />
            <.input field={@form[:purchased_on]} type="date" label="Gekauft am" />
            <.input field={@form[:discogs_release_id]} type="number" label="Discogs-Release-ID" />
          </div>
          <.input field={@form[:notes]} type="textarea" label="Notizen" rows="3" />

          <div class="flex gap-2 pt-4">
            <.button variant="primary" phx-disable-with="Speichern…" id="save-copy">
              Speichern
            </.button>
            <.button navigate={~p"/albums/#{@album}"}>Abbrechen</.button>
          </div>
        </.form>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    {:ok, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :new, %{"id" => album_id}) do
    actor = socket.assigns.current_user
    album = Records.get_album!(album_id, load: [:artist], actor: actor)

    form =
      AshPhoenix.Form.for_create(Copy, :create,
        as: "copy",
        actor: actor,
        # The album is fixed by the URL, not by a form field
        transform_params: fn params, _type -> Map.put(params, "album_id", album.id) end
      )

    socket
    |> assign(:page_title, "Exemplar hinzufügen")
    |> assign(:album, album)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    actor = socket.assigns.current_user
    copy = Records.get_copy!(id, load: [album: [:artist]], actor: actor)
    form = AshPhoenix.Form.for_update(copy, :update, as: "copy", actor: actor)

    socket
    |> assign(:page_title, "Exemplar bearbeiten")
    |> assign(:album, copy.album)
    |> assign(:form, to_form(form))
  end

  @impl true
  def handle_event("validate", %{"copy" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"copy" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _copy} ->
        {:noreply,
         socket
         |> put_flash(:info, "Exemplar gespeichert.")
         |> push_navigate(to: ~p"/albums/#{socket.assigns.album}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
