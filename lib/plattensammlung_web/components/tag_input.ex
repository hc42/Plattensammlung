defmodule PlattensammlungWeb.TagInput do
  @moduledoc """
  Reusable tag field with suggestions, to keep values consistent ("rock" and
  "Rock" become one). Used for genres, formats, label and country.

  * `multiple: true` – any number of tags, submitted as `form[field][]`
  * `multiple: false` – exactly one tag (a new one replaces it), submitted as `form[field]`

  The text field belongs to its own small form (`tag_entry_forms/1`, rendered
  outside the main form), so Enter adds a tag instead of saving everything.
  The LiveView keeps `@tags` (field => list) and `@tag_keys` (field => counter)
  and handles `"add_tag"` / `"remove_tag"` with `add/4` and `remove/4`.
  """
  use Phoenix.Component

  import PlattensammlungWeb.CoreComponents, only: [icon: 1]

  alias Phoenix.LiveView.JS

  attr :form_name, :string, required: true, doc: "e.g. \"album\""
  attr :field, :atom, required: true
  attr :label, :string, required: true
  attr :tags, :map, required: true, doc: "@tags"
  attr :keys, :map, required: true, doc: "@tag_keys"
  attr :suggestions, :list, default: []
  attr :multiple, :boolean, default: true
  attr :placeholder, :string, default: nil
  attr :maxlength, :integer, default: 50, doc: "per tag, as in the resource's constraints"

  def tag_input(assigns) do
    assigns =
      assigns
      |> assign(:values, Map.get(assigns.tags, assigns.field, []))
      |> assign(:key, Map.get(assigns.keys, assigns.field, 0))

    ~H"""
    <div class="fieldset mb-2" id={"tag-input-#{@field}"}>
      <span class="label mb-1">{@label}</span>
      <%= if @multiple do %>
        <input type="hidden" name={"#{@form_name}[#{@field}][]"} value="" />
        <input
          :for={value <- @values}
          type="hidden"
          name={"#{@form_name}[#{@field}][]"}
          value={value}
        />
      <% else %>
        <input type="hidden" name={"#{@form_name}[#{@field}]"} value={List.first(@values, "")} />
      <% end %>

      <div class="flex flex-wrap items-center gap-1.5" id={"#{@field}-tags"}>
        <span
          :for={value <- @values}
          class="badge badge-lg gap-1"
          id={"#{@field}-tag-#{tag_id(value)}"}
        >
          {value}
          <button
            type="button"
            phx-click="remove_tag"
            phx-value-field={@field}
            phx-value-tag={value}
            class="opacity-60 hover:opacity-100"
            aria-label={"#{value} entfernen"}
          >
            <.icon name="hero-x-mark-micro" class="size-4" />
          </button>
        </span>
        <%= if @multiple or @values == [] do %>
          <input
            type="text"
            id={"#{@field}-input-#{@key}"}
            name="tag"
            form={"#{@field}-entry"}
            list={"#{@field}-suggestions"}
            placeholder={@placeholder}
            maxlength={@maxlength}
            autocomplete="off"
            class="input input-sm w-44"
            phx-mounted={@key > 0 && JS.focus()}
          />
          <button
            type="submit"
            form={"#{@field}-entry"}
            class="btn btn-ghost btn-sm"
            id={"add-#{@field}-tag"}
          >
            Hinzufügen
          </button>
        <% end %>
      </div>
      <datalist id={"#{@field}-suggestions"}>
        <option :for={suggestion <- @suggestions -- @values} value={suggestion} />
      </datalist>
    </div>
    """
  end

  @doc "The small entry forms; render them outside the main form."
  attr :fields, :list, required: true

  def tag_entry_forms(assigns) do
    ~H"""
    <form :for={field <- @fields} id={"#{field}-entry"} phx-submit="add_tag">
      <input type="hidden" name="field" value={field} />
    </form>
    """
  end

  # As in the resources: at most 20 genres or format tags
  @max_tags 20

  @doc """
  Adds tags typed into `field` (comma separated), at most #{@max_tags}. Matching suggestions win, so
  "rock" becomes "Rock". `config` maps each field to `%{multiple: bool, suggestions: list}`.
  """
  def add(socket, field, text, config) do
    with {field, %{} = opts} <- lookup(field, config) do
      new =
        text
        |> String.split(if(opts.multiple, do: ",", else: "\n"))
        |> Enum.map(&normalize(&1, opts.suggestions))
        |> Enum.reject(&(&1 == ""))

      current = Map.get(socket.assigns.tags, field, [])

      values =
        cond do
          new == [] ->
            current

          opts.multiple ->
            (current ++ new) |> Enum.uniq_by(&String.downcase/1) |> Enum.take(@max_tags)

          true ->
            [hd(new)]
        end

      socket
      |> Phoenix.Component.update(:tag_keys, &Map.update(&1, field, 1, fn key -> key + 1 end))
      |> put(field, values, opts)
    else
      _ -> socket
    end
  end

  @doc "Removes one tag of `field`."
  def remove(socket, field, tag, config) do
    with {field, %{} = opts} <- lookup(field, config) do
      put(socket, field, List.delete(Map.get(socket.assigns.tags, field, []), tag), opts)
    else
      _ -> socket
    end
  end

  @doc "Removes all tags of `field` (e.g. when the optional field is hidden)."
  def clear(socket, field) when is_atom(field) do
    Phoenix.Component.update(socket, :tags, &Map.put(&1, field, []))
  end

  # Updates @tags and the AshPhoenix form, so validation sees the same values
  defp put(socket, field, values, opts) do
    form = socket.assigns.form.source
    value = if opts.multiple, do: values, else: List.first(values)
    params = form |> AshPhoenix.Form.params() |> Map.put(Atom.to_string(field), value)

    socket
    |> Phoenix.Component.update(:tags, &Map.put(&1, field, values))
    |> Phoenix.Component.assign(
      :form,
      Phoenix.Component.to_form(AshPhoenix.Form.validate(form, params))
    )
  end

  # Only configured fields; never create atoms from user input
  defp lookup(name, config) do
    Enum.find(config, fn {field, _opts} -> Atom.to_string(field) == name end)
  end

  defp normalize(text, suggestions) do
    text = String.trim(text)
    Enum.find(suggestions, text, &(String.downcase(&1) == String.downcase(text)))
  end

  defp tag_id(value), do: value |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
end
