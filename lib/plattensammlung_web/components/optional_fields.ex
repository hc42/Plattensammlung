defmodule PlattensammlungWeb.OptionalFields do
  @moduledoc """
  Optional form fields like in Apple's Contacts app: a field only appears after
  its "+" button is pressed, and "−" removes it again (and clears its value).

  A LiveView keeps a `MapSet` of visible fields in `@visible` and handles the
  `"show_field"` / `"hide_field"` events with `show/3` and `hide/3`:

      <.optional_field form={@form} field={:label} label="Label" visible={@visible} focus={@focus}>
        <.input field={@form[:label]} label="Label" />
      </.optional_field>

      <.add_field_buttons fields={@optional_fields} visible={@visible} />

  A hidden field is still submitted as an empty value, so removing a field
  also deletes its value when the form is saved.
  """
  use Phoenix.Component

  import PlattensammlungWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  attr :form, :any, required: true
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :visible, :any, required: true, doc: "MapSet of visible fields"
  attr :focus, :atom, default: nil, doc: "the field that was just added gets the focus"
  slot :inner_block, required: true

  def optional_field(assigns) do
    ~H"""
    <%= if MapSet.member?(@visible, @field) do %>
      <div
        id={"field-#{@field}"}
        class="flex items-start gap-1"
        phx-mounted={
          @focus == @field &&
            JS.focus(to: "#field-#{@field} :is(input:not([type=hidden]), select, textarea)")
        }
      >
        <button
          type="button"
          phx-click="hide_field"
          phx-value-field={@field}
          class="btn btn-ghost btn-sm btn-circle mt-7 text-error"
          aria-label={"#{@label} entfernen"}
          id={"remove-#{@field}"}
        >
          <.icon name="hero-minus-circle-solid" class="size-5" />
        </button>
        <div class="min-w-0 flex-1">{render_slot(@inner_block)}</div>
      </div>
    <% else %>
      <input type="hidden" name={@form[@field].name} value="" />
    <% end %>
    """
  end

  attr :fields, :list, required: true, doc: "list of {field, label}"
  attr :visible, :any, required: true

  def add_field_buttons(assigns) do
    ~H"""
    <div :if={hidden_fields(@fields, @visible) != []} class="flex flex-wrap gap-1" id="add-fields">
      <button
        :for={{field, label} <- hidden_fields(@fields, @visible)}
        type="button"
        phx-click="show_field"
        phx-value-field={field}
        class="btn btn-ghost btn-sm text-success"
        id={"add-#{field}"}
      >
        <.icon name="hero-plus-circle-solid" class="size-5" />
        <span class="text-base-content">{label}</span>
      </button>
    </div>
    """
  end

  defp hidden_fields(fields, visible),
    do: Enum.reject(fields, fn {f, _} -> MapSet.member?(visible, f) end)

  @doc "Fields of `record` that already have a value (visible when editing)."
  def initially_visible(nil, _fields), do: MapSet.new()

  def initially_visible(record, fields) do
    for {field, _label} <- fields, present?(Map.get(record, field)), into: MapSet.new(), do: field
  end

  @doc "Shows a field (event value from `phx-value-field`)."
  def show(socket, field, fields) do
    case to_field(field, fields) do
      nil ->
        socket

      field ->
        socket
        |> Phoenix.Component.update(:visible, &MapSet.put(&1, field))
        |> Phoenix.Component.assign(:focus, field)
    end
  end

  @doc "Hides a field and clears its value in the AshPhoenix form `@form`."
  def hide(socket, field, fields) do
    case to_field(field, fields) do
      nil ->
        socket

      field ->
        form = socket.assigns.form.source
        params = form |> AshPhoenix.Form.params() |> Map.put(Atom.to_string(field), "")

        socket
        |> Phoenix.Component.update(:visible, &MapSet.delete(&1, field))
        |> Phoenix.Component.assign(:focus, nil)
        |> Phoenix.Component.assign(
          :form,
          Phoenix.Component.to_form(AshPhoenix.Form.validate(form, params))
        )
    end
  end

  # Only known fields; never create atoms from user input
  defp to_field(name, fields) do
    Enum.find_value(fields, fn {field, _label} -> Atom.to_string(field) == name && field end)
  end

  defp present?(nil), do: false
  defp present?(""), do: false
  defp present?([]), do: false
  defp present?(_value), do: true
end
