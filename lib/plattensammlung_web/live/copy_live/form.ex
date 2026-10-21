defmodule PlattensammlungWeb.CopyLive.Form do
  @moduledoc """
  Adds or edits a copy of an album. Every field is optional and only shown
  once it is added with "+" (see `PlattensammlungWeb.OptionalFields`).
  """
  use PlattensammlungWeb, :live_view

  import PlattensammlungWeb.OptionalFields

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Copy
  alias PlattensammlungWeb.OptionalFields

  @fields [
    format: "Format",
    label: "Label",
    catalog_number: "Katalognummer",
    barcode: "Barcode",
    country: "Land",
    pressing_year: "Jahr der Pressung",
    media_condition: "Zustand Platte",
    sleeve_condition: "Zustand Hülle",
    purchased_on: "Gekauft am",
    discogs_release_id: "Discogs-Release-ID",
    notes: "Notizen"
  ]

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
          <p :if={MapSet.size(@visible) == 0} class="pb-2 text-sm opacity-70" id="no-fields">
            Noch keine Angaben. Füge hinzu, was du festhalten möchtest.
          </p>

          <.optional_field
            :for={{field, label} <- @fields}
            form={@form}
            field={field}
            label={label}
            visible={@visible}
            focus={@focus}
          >
            <.copy_input form={@form} field={field} label={label} />
          </.optional_field>

          <div class="mt-3 border-t border-base-300 pt-3">
            <.add_field_buttons fields={@fields} visible={@visible} />
          </div>

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
    |> assign_fields(nil)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    actor = socket.assigns.current_user
    copy = Records.get_copy!(id, load: [album: [:artist]], actor: actor)
    form = AshPhoenix.Form.for_update(copy, :update, as: "copy", actor: actor)

    socket
    |> assign(:page_title, "Exemplar bearbeiten")
    |> assign(:album, copy.album)
    |> assign_fields(copy)
    |> assign(:form, to_form(form))
  end

  defp assign_fields(socket, copy) do
    socket
    |> assign(:fields, @fields)
    |> assign(:visible, OptionalFields.initially_visible(copy, @fields))
    |> assign(:focus, nil)
  end

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true

  defp copy_input(%{field: field} = assigns)
       when field in [:media_condition, :sleeve_condition] do
    ~H"""
    <.input
      field={@form[@field]}
      type="select"
      label={@label}
      prompt="–"
      options={condition_options()}
    />
    """
  end

  defp copy_input(%{field: field} = assigns)
       when field in [:pressing_year, :discogs_release_id] do
    ~H"""
    <.input field={@form[@field]} type="number" label={@label} />
    """
  end

  defp copy_input(%{field: :purchased_on} = assigns) do
    ~H"""
    <.input field={@form[:purchased_on]} type="date" label={@label} />
    """
  end

  defp copy_input(%{field: :notes} = assigns) do
    ~H"""
    <.input field={@form[:notes]} type="textarea" label={@label} rows="3" />
    """
  end

  defp copy_input(%{field: :barcode} = assigns) do
    ~H"""
    <.input field={@form[:barcode]} label={@label} inputmode="numeric" />
    """
  end

  defp copy_input(%{field: :format} = assigns) do
    ~H"""
    <.input field={@form[:format]} label={@label} placeholder="LP, 2LP, 7″ …" />
    """
  end

  defp copy_input(assigns) do
    ~H"""
    <.input field={@form[@field]} label={@label} />
    """
  end

  @impl true
  def handle_event("show_field", %{"field" => field}, socket) do
    {:noreply, OptionalFields.show(socket, field, @fields)}
  end

  def handle_event("hide_field", %{"field" => field}, socket) do
    {:noreply, OptionalFields.hide(socket, field, @fields)}
  end

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
