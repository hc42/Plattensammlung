defmodule PlattensammlungWeb.CopyLive.Form do
  @moduledoc """
  Adds or edits a copy of an album. Every field is optional and only shown
  once it is added with "+" (see `PlattensammlungWeb.OptionalFields`).
  """
  use PlattensammlungWeb, :live_view

  import PlattensammlungWeb.OptionalFields
  import PlattensammlungWeb.TagInput

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Copy
  alias PlattensammlungWeb.{OptionalFields, TagInput}

  # Picked from a list of earlier values to avoid spelling variants
  @tag_fields [:format, :label, :country]

  # Optional fields with their labels (a function: the labels depend on the language)
  defp fields do
    [
      format: field_label(:format),
      label: field_label(:label),
      catalog_number: field_label(:catalog_number),
      barcode: field_label(:barcode),
      country: field_label(:country),
      pressing_year: field_label(:pressing_year),
      media_condition: gettext("Media condition"),
      sleeve_condition: gettext("Sleeve condition"),
      purchased_on: gettext("Purchased on"),
      discogs_release_id: gettext("Discogs release ID"),
      notes: gettext("Notes")
    ]
  end

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
            {@album.artist.name} – {@album.title}. {gettext("Everything is optional.")}
          </p>
        </div>

        <.form for={@form} id="copy-form" phx-change="validate" phx-submit="save">
          <p :if={MapSet.size(@visible) == 0} class="pb-2 text-sm opacity-70" id="no-fields">
            {gettext("No details yet. Add what you want to keep track of.")}
          </p>

          <.optional_field
            :for={{field, label} <- @fields}
            form={@form}
            field={field}
            label={label}
            visible={@visible}
            focus={@focus}
          >
            <.tag_input
              :if={field in @tag_fields}
              form_name="copy"
              field={field}
              label={label}
              tags={@tags}
              keys={@tag_keys}
              suggestions={@suggestions[field]}
              multiple={field == :format}
              placeholder={tag_placeholder(field)}
              maxlength={if field == :format, do: 50, else: 100}
            />
            <.copy_input :if={field not in @tag_fields} form={@form} field={field} label={label} />
          </.optional_field>

          <div class="mt-3 border-t border-base-300 pt-3">
            <.add_field_buttons fields={@fields} visible={@visible} />
          </div>

          <div class="flex gap-2 pt-4">
            <.button variant="primary" phx-disable-with={gettext("Saving …")} id="save-copy">
              {gettext("Save")}
            </.button>
            <.button navigate={~p"/albums/#{@album}"}>{gettext("Cancel")}</.button>
          </div>
        </.form>

        <%!-- Entry forms of the tag fields: Enter adds a tag instead of saving --%>
        <.tag_entry_forms fields={@tag_fields} />
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(params, _session, socket) do
    socket = apply_action(socket, socket.assigns.live_action, params)

    # Anyone may add an own copy of any album; editing is for the copy's owner
    case socket.assigns[:copy] do
      nil ->
        {:ok, socket}

      copy ->
        case PlattensammlungWeb.Ownership.require_copy_owner(socket, copy) do
          :ok -> {:ok, socket}
          {:redirect, socket} -> {:ok, socket}
        end
    end
  end

  defp apply_action(socket, :new, %{"id" => album_id}) do
    actor = socket.assigns.current_user
    album = Records.get_album!(album_id, load: [:artist], actor: actor)

    form =
      AshPhoenix.Form.for_create(Copy, :create,
        as: "copy",
        actor: actor,
        prepare_params: &prepare_params/2,
        # The album is fixed by the URL, not by a form field
        transform_params: fn params, _type -> Map.put(params, "album_id", album.id) end
      )

    socket
    |> assign(:page_title, gettext("Add a copy"))
    |> assign(:copy, nil)
    |> assign(:album, album)
    |> assign_fields(nil)
    |> assign(:form, to_form(form))
  end

  defp apply_action(socket, :edit, %{"id" => id}) do
    actor = socket.assigns.current_user
    copy = Records.get_copy!(id, load: [album: [:artist]], actor: actor)

    form =
      AshPhoenix.Form.for_update(copy, :update,
        as: "copy",
        actor: actor,
        prepare_params: &prepare_params/2
      )

    socket
    |> assign(:page_title, gettext("Edit copy"))
    |> assign(:copy, copy)
    |> assign(:album, copy.album)
    |> assign_fields(copy)
    |> assign(:form, to_form(form))
  end

  defp assign_fields(socket, copy) do
    socket
    |> assign(:fields, fields())
    |> assign(:tag_fields, @tag_fields)
    |> assign(:visible, OptionalFields.initially_visible(copy, fields()))
    |> assign(:focus, nil)
    |> assign(:tag_keys, %{})
    |> assign(:tags, %{
      format: (copy && copy.format) || [],
      label: List.wrap(copy && copy.label),
      country: List.wrap(copy && copy.country)
    })
    |> assign(:suggestions, suggestions(socket.assigns.current_user))
  end

  # Values used so far in the collection, for consistent spelling
  defp suggestions(actor) do
    copies = Plattensammlung.Records.Copy |> Ash.read!(actor: actor)

    %{
      format: copies |> Enum.flat_map(& &1.format) |> distinct(),
      label: copies |> Enum.map(& &1.label) |> distinct(),
      country: copies |> Enum.map(& &1.country) |> distinct()
    }
  end

  defp distinct(values),
    do: values |> Enum.reject(&(&1 in [nil, ""])) |> Enum.uniq() |> Enum.sort()

  defp tag_placeholder(:format), do: gettext("e.g. %{example}", example: "LP")
  defp tag_placeholder(:label), do: gettext("e.g. %{example}", example: "Apple Records")
  defp tag_placeholder(:country), do: gettext("e.g. %{example}", example: "UK")

  defp tag_config(socket) do
    Map.new(@tag_fields, fn field ->
      {field, %{multiple: field == :format, suggestions: socket.assigns.suggestions[field]}}
    end)
  end

  # Formats arrive as copy[format][] (tags plus an empty marker) or as a single
  # empty value when the field is hidden; the action expects a clean list
  defp prepare_params(%{"format" => formats} = params, _type) when is_list(formats) do
    Map.put(params, "format", formats |> Enum.map(&String.trim/1) |> Enum.reject(&(&1 == "")))
  end

  defp prepare_params(%{"format" => ""} = params, _type), do: Map.put(params, "format", [])
  defp prepare_params(params, _type), do: params

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

  defp copy_input(%{field: :pressing_year} = assigns) do
    ~H"""
    <.input field={@form[:pressing_year]} type="number" label={@label} min="1900" max="2100" />
    """
  end

  # An id, not a quantity: no number spinner, but a digit keypad on phones
  defp copy_input(%{field: :discogs_release_id} = assigns) do
    ~H"""
    <.input
      field={@form[:discogs_release_id]}
      type="text"
      inputmode="numeric"
      autocomplete="off"
      maxlength="12"
      label={@label}
    />
    """
  end

  defp copy_input(%{field: :purchased_on} = assigns) do
    ~H"""
    <.input field={@form[:purchased_on]} type="date" label={@label} />
    """
  end

  defp copy_input(%{field: :notes} = assigns) do
    ~H"""
    <.input field={@form[:notes]} type="textarea" label={@label} rows="3" maxlength="2000" />
    """
  end

  defp copy_input(%{field: :barcode} = assigns) do
    ~H"""
    <.input field={@form[:barcode]} label={@label} inputmode="numeric" maxlength="20" />
    """
  end

  defp copy_input(assigns) do
    ~H"""
    <.input field={@form[@field]} label={@label} maxlength="100" />
    """
  end

  @impl true
  def handle_event("show_field", %{"field" => field}, socket) do
    {:noreply, OptionalFields.show(socket, field, fields())}
  end

  def handle_event("hide_field", %{"field" => field}, socket) do
    socket =
      case Enum.find(@tag_fields, &(Atom.to_string(&1) == field)) do
        nil -> socket
        tag_field -> TagInput.clear(socket, tag_field)
      end

    {:noreply, OptionalFields.hide(socket, field, fields())}
  end

  def handle_event("add_tag", %{"field" => field, "tag" => text}, socket) do
    {:noreply, TagInput.add(socket, field, text, tag_config(socket))}
  end

  def handle_event("remove_tag", %{"field" => field, "tag" => tag}, socket) do
    {:noreply, TagInput.remove(socket, field, tag, tag_config(socket))}
  end

  def handle_event("validate", %{"copy" => params}, socket) do
    {:noreply, assign(socket, :form, AshPhoenix.Form.validate(socket.assigns.form, params))}
  end

  def handle_event("save", %{"copy" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.form, params: params) do
      {:ok, _copy} ->
        {:noreply,
         socket
         |> put_flash(:info, gettext("Copy saved."))
         |> push_navigate(to: ~p"/albums/#{socket.assigns.album}")}

      {:error, form} ->
        {:noreply, assign(socket, :form, form)}
    end
  end
end
