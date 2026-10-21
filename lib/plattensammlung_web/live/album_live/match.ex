defmodule PlattensammlungWeb.AlbumLive.Match do
  @moduledoc """
  Updates an existing album from Discogs/MusicBrainz (`Album.find_matches`,
  `Album.apply_match`). Each candidate shows which fields it would fill;
  "Ergänzen" fills empty fields, "Überschreiben" replaces all it has.

  A scanned or typed barcode finds the exact pressing; its details (label,
  catalog number, …) can go into one of the album's copies or a new copy.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.Records
  alias Plattensammlung.Records.AlbumMatch

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-2xl space-y-6">
        <div>
          <.link navigate={~p"/albums/#{@album}"} class="text-sm opacity-70 hover:opacity-100">
            <.icon name="hero-arrow-left-micro" class="size-4" /> {@album.title}
          </.link>
          <h1 class="mt-2 text-2xl font-bold">Daten abgleichen</h1>
          <p class="text-sm opacity-70">
            {@album.artist.name} – {@album.title}. Künstler und Titel bleiben, wie du sie erfasst hast.
          </p>
        </div>

        <.barcode_scanner id="match-scanner" />

        <.form for={@search_form} id="match-form" phx-submit="search" class="flex gap-2">
          <label class="input flex-1">
            <.icon name="hero-magnifying-glass" class="size-4 opacity-50" />
            <input
              type="search"
              name="query"
              id="match-query"
              value={@search_form[:query].value}
              autocomplete="off"
            />
          </label>
          <.button variant="primary" id="match-search" disabled={@loading}>Suchen</.button>
        </.form>

        <p :if={@linked?} class="text-xs opacity-60" id="linked-hint">
          Direkt über die gespeicherte Discogs- bzw. MusicBrainz-Verknüpfung geladen.
          Andere Treffer findest du über die Suche.
        </p>

        <div :if={@loading} id="match-loading" class="flex items-center gap-2 py-6 opacity-70">
          <span class="loading loading-spinner loading-sm"></span> Suche läuft …
        </div>

        <p :if={@error} id="match-error" class="alert alert-error alert-soft">
          Die Suche hat nicht geklappt. Bitte später noch einmal versuchen.
        </p>

        <p
          :if={@searched? and not @loading and @candidates == %{} and !@error}
          id="no-matches"
          class="opacity-70"
        >
          Nichts gefunden. Versuch es mit einem anderen Suchbegriff.
        </p>

        <.form
          :if={@pressing?}
          for={%{}}
          id="copy-target-form"
          phx-change="copy_target"
          class="rounded-lg border border-base-300 p-3 text-sm"
        >
          <label for="copy-target" class="font-medium">Pressungsdaten (Barcode, Label, …) übernehmen in</label>
          <select id="copy-target" name="target" class="select select-sm mt-2 w-full">
            <option
              :for={{value, label} <- copy_target_options(@album)}
              value={value}
              selected={value == @copy_target}
            >
              {label}
            </option>
          </select>
        </.form>

        <ul id="matches" phx-update="stream" class="divide-y divide-base-300">
          <.lookup_result
            :for={{dom_id, item} <- @streams.matches}
            id={dom_id}
            result={item.result}
          >
            <p class="text-xs" id={"changes-#{item.index}"}>
              <%= if item.fill == [] do %>
                <span class="opacity-60">Album: alle Felder sind schon gefüllt.</span>
              <% else %>
                <span class="font-medium">Album ergänzt:</span> {Enum.join(item.fill, ", ")}
              <% end %>
            </p>
            <p
              :if={copy_preview(item.result, @copy_target, @album)}
              class="text-xs"
              id={"copy-changes-#{item.index}"}
            >
              <span class="font-medium">Exemplar:</span> {copy_preview(
                item.result,
                @copy_target,
                @album
              )}
            </p>
            <:actions>
              <button
                phx-click="apply"
                phx-value-index={item.index}
                phx-value-mode="fill"
                phx-disable-with="…"
                disabled={item.fill == [] and !copy_preview(item.result, @copy_target, @album)}
                class="btn btn-primary btn-sm"
                id={"fill-#{item.index}"}
              >
                Ergänzen
              </button>
              <button
                phx-click="apply"
                phx-value-index={item.index}
                phx-value-mode="overwrite"
                phx-disable-with="…"
                disabled={item.overwrite == [] and !copy_preview(item.result, @copy_target, @album)}
                data-confirm={"Überschreibt: #{Enum.join(item.overwrite, ", ")}"}
                class="btn btn-ghost btn-sm"
                id={"overwrite-#{item.index}"}
              >
                Überschreiben
              </button>
            </:actions>
          </.lookup_result>
        </ul>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    album = Records.get_album!(id, load: [:artist, :copies], actor: socket.assigns.current_user)

    case PlattensammlungWeb.Ownership.require_owner(socket, album) do
      :ok -> mount_owner(socket, album)
      {:redirect, socket} -> {:ok, socket}
    end
  end

  defp mount_owner(socket, album) do
    linked? = not is_nil(album.discogs_master_id || album.musicbrainz_release_group_id)

    {:ok,
     socket
     |> assign(:page_title, "Daten abgleichen")
     |> assign(:album, album)
     |> assign(:linked?, linked?)
     |> assign(:pressing?, false)
     |> assign(:copy_target, default_copy_target(album))
     |> assign(:search_form, to_form(%{"query" => "#{album.artist.name} #{album.title}"}))
     |> start_search(nil)}
  end

  @impl true
  def handle_event("search", %{"query" => query}, socket) do
    {:noreply,
     socket
     |> assign(:linked?, false)
     |> assign(:search_form, to_form(%{"query" => query}))
     |> start_search(query)}
  end

  # Sent by the BarcodeScanner hook
  def handle_event("scanned", %{"code" => code}, socket) do
    case Plattensammlung.Lookup.barcode(code) do
      nil ->
        {:noreply, put_flash(socket, :error, "Das sieht nicht nach einem Barcode aus.")}

      barcode ->
        handle_event("search", %{"query" => barcode}, socket)
    end
  end

  def handle_event("copy_target", %{"target" => target}, socket) do
    {:noreply, socket |> assign(:copy_target, target) |> restream()}
  end

  def handle_event("apply", %{"index" => index, "mode" => mode}, socket) do
    item = Map.fetch!(socket.assigns.candidates, String.to_integer(index))
    mode = if mode == "overwrite", do: :overwrite, else: :fill

    pressing_opts =
      case socket.assigns.copy_target do
        "new" -> %{new_copy: true}
        "none" -> %{}
        copy_id -> %{copy_id: copy_id}
      end

    case Records.apply_match(socket.assigns.album, item.result, mode, pressing_opts,
           actor: socket.assigns.current_user
         ) do
      {:ok, album} ->
        {:noreply,
         socket
         |> put_flash(:info, "Daten übernommen.")
         |> push_navigate(to: ~p"/albums/#{album}")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, "Die Daten konnten nicht übernommen werden.")}
    end
  end

  @impl true
  def handle_async(:matches, {:ok, {:ok, results}}, socket) do
    album = socket.assigns.album

    items =
      results
      |> Enum.with_index()
      |> Enum.map(fn {result, index} ->
        %{
          index: index,
          result: result,
          fill: album |> AlbumMatch.changes(result, :fill) |> AlbumMatch.labels(),
          overwrite: album |> AlbumMatch.changes(result, :overwrite) |> AlbumMatch.labels()
        }
      end)

    {:noreply,
     socket
     |> assign(:loading, false)
     |> assign(:pressing?, Enum.any?(results, &AlbumMatch.pressing?/1))
     |> assign(:candidates, Map.new(items, &{&1.index, &1}))
     |> stream(:matches, items, reset: true, dom_id: &"match-#{&1.index}")}
  end

  def handle_async(:matches, _failure, socket) do
    {:noreply, socket |> assign(:loading, false) |> assign(:error, true)}
  end

  # The copy preview depends on @copy_target, so stream items must re-render
  defp restream(socket) do
    items = socket.assigns.candidates |> Map.values() |> Enum.sort_by(& &1.index)
    stream(socket, :matches, items, reset: true, dom_id: &"match-#{&1.index}")
  end

  # First copy without barcode; otherwise don't touch existing copies
  defp default_copy_target(album) do
    case Enum.find(album.copies, &is_nil(&1.barcode)) do
      nil -> "none"
      copy -> copy.id
    end
  end

  defp copy_target_options(album) do
    copies =
      album.copies
      |> Enum.with_index(1)
      |> Enum.map(fn {copy, number} -> {copy.id, "Exemplar #{number}#{copy_summary(copy)}"} end)

    copies ++ [{"new", "Neues Exemplar anlegen"}, {"none", "Nicht übernehmen"}]
  end

  defp copy_summary(copy) do
    case Enum.reject([Enum.join(copy.format, ", "), copy.label, copy.barcode], &(&1 in [nil, ""])) do
      [] -> ""
      parts -> " (" <> Enum.join(parts, " · ") <> ")"
    end
  end

  # Text describing what happens to the chosen copy, nil if nothing
  defp copy_preview(result, target, album) do
    cond do
      not AlbumMatch.pressing?(result) -> nil
      target == "none" -> nil
      target == "new" -> "wird als neues Exemplar angelegt"
      true -> copy_fill_preview(result, Enum.find(album.copies, &(&1.id == target)))
    end
  end

  defp copy_fill_preview(_result, nil), do: nil

  defp copy_fill_preview(result, copy) do
    case copy |> AlbumMatch.copy_changes(result, :fill) |> AlbumMatch.labels() do
      [] -> nil
      labels -> "ergänzt " <> Enum.join(labels, ", ")
    end
  end

  defp start_search(socket, query) do
    album_id = socket.assigns.album.id
    actor = socket.assigns.current_user

    socket
    |> assign(:loading, true)
    |> assign(:error, false)
    |> assign(:searched?, true)
    |> assign(:candidates, %{})
    |> stream(:matches, [], reset: true, dom_id: &"match-#{&1.index}")
    |> start_async(:matches, fn -> Records.find_matches(album_id, query, actor: actor) end)
  end
end
