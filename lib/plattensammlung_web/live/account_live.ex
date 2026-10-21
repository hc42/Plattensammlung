defmodule PlattensammlungWeb.AccountLive do
  @moduledoc """
  Account settings: passkeys (add/remove) and API keys for the JSON API.
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash} current_user={@current_user}>
      <div class="mx-auto max-w-2xl space-y-10">
        <div class="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1 class="text-2xl font-bold">Konto</h1>
            <p class="text-sm opacity-70">{@current_user.email}</p>
          </div>
          <.link href={~p"/sign-out"} method="delete" class="btn btn-ghost btn-sm" id="sign-out">
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> Abmelden
          </.link>
        </div>

        <section class="space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Passkeys</h2>
            <p class="text-sm opacity-70">
              Anmelden mit Fingerabdruck, Gesicht oder Geräte-PIN statt E-Mail-Link.
              Ein Passkey gilt nur für die Adresse, unter der du ihn anlegst ({@host}).
            </p>
          </div>

          <ul id="passkeys" class="divide-y divide-base-300 rounded-lg border border-base-300">
            <li :if={@passkeys == []} class="p-4 text-sm opacity-70">Noch keine Passkeys.</li>
            <li
              :for={passkey <- @passkeys}
              id={"passkey-#{passkey.id}"}
              class="flex items-center gap-3 p-4"
            >
              <.icon name="hero-finger-print" class="size-5 opacity-60" />
              <div class="flex-1 text-sm">
                <p class="font-medium">{passkey.name || "Passkey"}</p>
                <p class="opacity-60">
                  angelegt {format_date(passkey.inserted_at)}<span :if={passkey.last_used_at}>,
                  zuletzt benutzt {format_date(passkey.last_used_at)}</span>
                </p>
              </div>
              <button
                phx-click="delete_passkey"
                phx-value-id={passkey.id}
                data-confirm="Diesen Passkey entfernen?"
                class="btn btn-ghost btn-sm text-error"
                id={"delete-passkey-#{passkey.id}"}
                aria-label="Passkey entfernen"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </li>
          </ul>

          <form id="passkey-form" phx-hook="PasskeyRegister" class="flex gap-2">
            <input
              type="text"
              name="name"
              placeholder="Name, z. B. MacBook oder iPhone"
              maxlength="60"
              class="input flex-1"
            />
            <button class="btn btn-primary" id="add-passkey">
              <.icon name="hero-plus" class="size-4" /> Passkey hinzufügen
            </button>
          </form>
          <p :if={@passkey_error} id="passkey-error" class="text-sm text-error">{@passkey_error}</p>
        </section>

        <section class="space-y-4">
          <div>
            <h2 class="text-lg font-semibold">API-Keys</h2>
            <p class="text-sm opacity-70">
              Für Skripte und Apps: <code>Authorization: Bearer &lt;Key&gt;</code>
              an <.link href={~p"/api/json/swaggerui"} class="link">/api/json</.link>.
            </p>
          </div>

          <div
            :if={@new_api_key}
            id="new-api-key"
            class="alert alert-success alert-soft block space-y-2"
          >
            <p class="text-sm font-medium">
              Neuer Key – jetzt kopieren, er wird nur einmal angezeigt:
            </p>
            <code class="block break-all rounded bg-base-100 p-2 text-xs">{@new_api_key}</code>
          </div>

          <ul id="api-keys" class="divide-y divide-base-300 rounded-lg border border-base-300">
            <li :if={@api_keys == []} class="p-4 text-sm opacity-70">Noch keine API-Keys.</li>
            <li :for={key <- @api_keys} id={"api-key-#{key.id}"} class="flex items-center gap-3 p-4">
              <.icon name="hero-key" class="size-5 opacity-60" />
              <div class="flex-1 text-sm">
                <p class="font-medium">angelegt {format_date(key.inserted_at)}</p>
                <p class={["opacity-60", !key.valid && "text-error"]}>
                  {if key.valid, do: "gültig bis", else: "abgelaufen am"} {format_date(key.expires_at)}
                </p>
              </div>
              <button
                phx-click="delete_api_key"
                phx-value-id={key.id}
                data-confirm="Diesen API-Key löschen? Programme, die ihn nutzen, verlieren den Zugriff."
                class="btn btn-ghost btn-sm text-error"
                id={"delete-api-key-#{key.id}"}
                aria-label="API-Key löschen"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </li>
          </ul>

          <.form for={@api_key_form} id="api-key-form" phx-submit="create_api_key" class="flex gap-2">
            <select name="valid_for" class="select w-48">
              <option value="30">30 Tage gültig</option>
              <option value="365" selected>1 Jahr gültig</option>
            </select>
            <button class="btn" id="create-api-key">
              <.icon name="hero-plus" class="size-4" /> API-Key erzeugen
            </button>
          </.form>
        </section>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Konto")
     |> assign(:host, socket.host_uri.host)
     |> assign(:passkey_error, nil)
     |> assign(:new_api_key, nil)
     |> assign(:api_key_form, to_form(%{}))
     |> load_passkeys()
     |> load_api_keys()}
  end

  @impl true
  def handle_event("passkey_registered", _params, socket) do
    {:noreply,
     socket
     |> assign(:passkey_error, nil)
     |> put_flash(:info, "Passkey hinzugefügt.")
     |> load_passkeys()}
  end

  def handle_event("passkey_failed", %{"error" => error}, socket) do
    {:noreply, assign(socket, :passkey_error, error)}
  end

  def handle_event("delete_passkey", %{"id" => id}, socket) do
    passkey = Enum.find(socket.assigns.passkeys, &(&1.id == id))
    Accounts.destroy_passkey!(passkey, actor: actor(socket))

    {:noreply, socket |> put_flash(:info, "Passkey entfernt.") |> load_passkeys()}
  end

  def handle_event("create_api_key", %{"valid_for" => days}, socket) do
    days = if days in ["30", "365"], do: String.to_integer(days), else: 365
    expires_at = DateTime.add(DateTime.utc_now(), days, :day)
    api_key = Accounts.create_api_key!(expires_at, actor: actor(socket))

    {:noreply,
     socket
     |> assign(:new_api_key, api_key.__metadata__.plaintext_api_key)
     |> load_api_keys()}
  end

  def handle_event("delete_api_key", %{"id" => id}, socket) do
    api_key = Enum.find(socket.assigns.api_keys, &(&1.id == id))
    Accounts.destroy_api_key!(api_key, actor: actor(socket))

    {:noreply, socket |> put_flash(:info, "API-Key gelöscht.") |> load_api_keys()}
  end

  defp load_passkeys(socket) do
    passkeys = Accounts.list_passkeys!(actor: actor(socket), query: [sort: [inserted_at: :asc]])
    assign(socket, :passkeys, passkeys)
  end

  defp load_api_keys(socket) do
    api_keys =
      Accounts.list_api_keys!(
        actor: actor(socket),
        load: [:valid],
        query: [sort: [inserted_at: :desc]]
      )

    assign(socket, :api_keys, api_keys)
  end

  defp actor(socket), do: socket.assigns.current_user

  defp format_date(datetime), do: Calendar.strftime(datetime, "%d.%m.%Y")
end
