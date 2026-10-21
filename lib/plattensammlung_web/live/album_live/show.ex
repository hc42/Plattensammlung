defmodule PlattensammlungWeb.AlbumLive.Show do
  @moduledoc """
  Album details with its copies, wishlist toggle and Discogs links.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.Records

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <.link navigate={back_path(@album)} class="text-sm opacity-70 hover:opacity-100">
        <.icon name="hero-arrow-left-micro" class="size-4" />
        {if @album.owned, do: "Sammlung", else: "Wunschliste"}
      </.link>

      <div class="grid gap-8 md:grid-cols-[18rem_1fr]">
        <.cover album={@album} class="w-full max-w-72" />

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

          <div id="ownership" class="rounded-lg bg-base-200 p-4 text-sm">
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

          <div class="flex flex-wrap gap-2">
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

          <a
            :if={@album.discogs_url}
            href={@album.discogs_url}
            target="_blank"
            rel="noopener"
            class="link inline-flex items-center gap-1 text-sm"
            id="discogs-link"
          >
            Auf Discogs ansehen <.icon name="hero-arrow-top-right-on-square-micro" class="size-4" />
          </a>
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
              <div class="flex gap-1">
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
              <%= for {label, value} <- copy_details(copy), value not in [nil, ""] do %>
                <dt class="opacity-60">{label}</dt>
                <dd>{value}</dd>
              <% end %>
            </dl>
            <p :if={copy.notes} class="mt-2 whitespace-pre-line opacity-80">{copy.notes}</p>
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
    {:ok, load_album(socket, id)}
  end

  @impl true
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
     |> push_navigate(to: back_path(album))}
  end

  def handle_event("delete_copy", %{"id" => id}, socket) do
    actor = socket.assigns.current_user
    id |> Records.get_copy!(actor: actor) |> Records.destroy_copy!(actor: actor)

    {:noreply,
     socket
     |> put_flash(:info, "Exemplar gelöscht.")
     |> load_album(socket.assigns.album.id)}
  end

  defp load_album(socket, id) do
    album =
      Records.get_album!(id,
        actor: socket.assigns.current_user,
        load: [:artist, :owned, :copy_count, :discogs_url, copies: [:discogs_url]]
      )

    socket
    |> assign(:album, album)
    |> assign(:page_title, "#{album.artist.name} – #{album.title}")
  end

  defp back_path(%{owned: false, wanted: true}), do: ~p"/wishlist"
  defp back_path(_album), do: ~p"/"

  defp copy_heading(copy) do
    [copy.format, copy.label, copy.pressing_year && to_string(copy.pressing_year)]
    |> Enum.reject(&(&1 in [nil, ""]))
    |> case do
      [] -> "Exemplar"
      parts -> Enum.join(parts, " · ")
    end
  end

  defp copy_details(copy) do
    [
      {"Katalognummer", copy.catalog_number},
      {"Barcode", copy.barcode},
      {"Land", copy.country},
      {"Zustand Platte", condition_label(copy.media_condition)},
      {"Zustand Hülle", condition_label(copy.sleeve_condition)},
      {"Gekauft am", copy.purchased_on && Calendar.strftime(copy.purchased_on, "%d.%m.%Y")},
      {"Preis", copy.purchase_price && format_price(copy.purchase_price)},
      {"Lagerort", copy.location}
    ]
  end

  defp format_price(price) do
    price
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> String.replace(".", ",")
    |> Kernel.<>(" €")
  end
end
