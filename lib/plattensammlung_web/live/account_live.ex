defmodule PlattensammlungWeb.AccountLive do
  @moduledoc """
  Account settings: display name, language (ADR 0021), passkeys and API keys
  for the JSON API.
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
            <h1 class="text-2xl font-bold">{gettext("Account")}</h1>
            <p class="text-sm opacity-70">{@current_user.email}</p>
          </div>
          <.link href={~p"/sign-out"} method="delete" class="btn btn-ghost btn-sm" id="sign-out">
            <.icon name="hero-arrow-right-start-on-rectangle" class="size-4" /> {gettext("Sign out")}
          </.link>
        </div>

        <section class="space-y-3">
          <div>
            <h2 class="text-lg font-semibold">{gettext("Display name")}</h2>
            <p class="text-sm opacity-70">
              {gettext("This is how other collectors see you. Your e-mail address stays private.")}
            </p>
          </div>
          <.form for={@profile_form} id="profile-form" phx-submit="save_profile" class="flex gap-2">
            <input
              type="text"
              name="display_name"
              value={@profile_form[:display_name].value}
              maxlength="40"
              placeholder={gettext("e.g. Hans")}
              class="input flex-1"
              aria-label={gettext("Display name")}
            />
            <button class="btn" id="save-profile">{gettext("Save")}</button>
          </.form>
        </section>

        <section class="space-y-3">
          <div>
            <h2 class="text-lg font-semibold">{gettext("Language")}</h2>
            <p class="text-sm opacity-70">
              {gettext("Automatic follows the language of your browser.")}
            </p>
          </div>
          <form id="locale-form" phx-change="save_locale">
            <select name="locale" class="select w-64" aria-label={gettext("Language")}>
              <option value="" selected={is_nil(@current_user.locale)}>
                {gettext("Automatic (browser)")}
              </option>
              <option value="en" selected={@current_user.locale == "en"}>English</option>
              <option value="de" selected={@current_user.locale == "de"}>Deutsch</option>
            </select>
          </form>
        </section>

        <section class="space-y-4">
          <div>
            <h2 class="text-lg font-semibold">Passkeys</h2>
            <p class="text-sm opacity-70">
              {gettext("Sign in with fingerprint, face or device PIN instead of an e-mail link.")}
            </p>
          </div>

          <ul id="passkeys" class="divide-y divide-base-300 rounded-lg border border-base-300">
            <li :if={@passkeys == []} class="p-4 text-sm opacity-70">
              {gettext("No passkeys yet.")}
            </li>
            <li
              :for={passkey <- @passkeys}
              id={"passkey-#{passkey.id}"}
              class="flex items-center gap-3 p-4"
            >
              <.icon name="hero-finger-print" class="size-5 opacity-60" />
              <.form
                :if={@renaming == passkey.id}
                for={@rename_form}
                id={"rename-passkey-form-#{passkey.id}"}
                phx-submit="rename_passkey"
                class="flex flex-1 gap-2"
              >
                <input type="hidden" name="passkey_id" value={passkey.id} />
                <input
                  type="text"
                  name="name"
                  value={@rename_form[:name].value}
                  maxlength="60"
                  class="input input-sm flex-1"
                  aria-label={gettext("Name of the passkey")}
                  phx-mounted={JS.focus()}
                />
                <button class="btn btn-primary btn-sm">{gettext("Save")}</button>
                <button type="button" phx-click="cancel_rename" class="btn btn-ghost btn-sm">
                  {gettext("Cancel")}
                </button>
              </.form>
              <div :if={@renaming != passkey.id} class="flex-1 text-sm">
                <p class="font-medium">{passkey.name || "Passkey"}</p>
                <p class="opacity-60">
                  {gettext("created %{date}", date: format_date(passkey.inserted_at))}<span :if={
                    passkey.last_used_at
                  }>, {gettext("last used %{date}", date: format_date(passkey.last_used_at))}</span>
                </p>
              </div>
              <button
                :if={@renaming != passkey.id}
                phx-click="start_rename"
                phx-value-id={passkey.id}
                class="btn btn-ghost btn-sm"
                id={"rename-passkey-#{passkey.id}"}
                aria-label={gettext("Rename passkey")}
              >
                <.icon name="hero-pencil-square" class="size-4" />
              </button>
              <button
                :if={@renaming != passkey.id}
                phx-click="delete_passkey"
                phx-value-id={passkey.id}
                data-confirm={gettext("Remove this passkey?")}
                class="btn btn-ghost btn-sm text-error"
                id={"delete-passkey-#{passkey.id}"}
                aria-label={gettext("Remove passkey")}
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </li>
          </ul>

          <form
            id="passkey-form"
            phx-hook="PasskeyRegister"
            data-msg-cancelled={gettext("Cancelled.")}
            data-msg-unsupported={gettext("Passkeys need HTTPS or localhost.")}
            data-msg-unknown={gettext("Unknown error")}
            class="flex gap-2"
          >
            <input
              type="text"
              name="name"
              placeholder={gettext("Name, e.g. MacBook or iPhone")}
              maxlength="60"
              class="input flex-1"
            />
            <button class="btn btn-primary" id="add-passkey">
              <.icon name="hero-plus" class="size-4" /> {gettext("Add passkey")}
            </button>
          </form>
          <p :if={@passkey_error} id="passkey-error" class="text-sm text-error">{@passkey_error}</p>
        </section>

        <section class="space-y-4">
          <div>
            <h2 class="text-lg font-semibold">{gettext("API keys")}</h2>
            <p class="text-sm opacity-70">
              {gettext("For scripts and apps:")} <code>Authorization: Bearer &lt;Key&gt;</code>
              → <.link href={~p"/api/json/swaggerui"} class="link">/api/json</.link>
            </p>
          </div>

          <div
            :if={@new_api_key}
            id="new-api-key"
            class="alert alert-success alert-soft block space-y-2"
          >
            <p class="text-sm font-medium">
              {gettext("New key – copy it now, it is shown only once:")}
            </p>
            <code class="block break-all rounded bg-base-100 p-2 text-xs">{@new_api_key}</code>
          </div>

          <ul id="api-keys" class="divide-y divide-base-300 rounded-lg border border-base-300">
            <li :if={@api_keys == []} class="p-4 text-sm opacity-70">
              {gettext("No API keys yet.")}
            </li>
            <li :for={key <- @api_keys} id={"api-key-#{key.id}"} class="flex items-center gap-3 p-4">
              <.icon name="hero-key" class="size-5 opacity-60" />
              <div class="flex-1 text-sm">
                <p class="font-medium">
                  {gettext("created %{date}", date: format_date(key.inserted_at))}
                </p>
                <p class={["opacity-60", !key.valid && "text-error"]}>
                  {if key.valid,
                    do: gettext("valid until %{date}", date: format_date(key.expires_at)),
                    else: gettext("expired on %{date}", date: format_date(key.expires_at))}
                </p>
              </div>
              <button
                phx-click="delete_api_key"
                phx-value-id={key.id}
                data-confirm={gettext("Delete this API key? Programs using it lose access.")}
                class="btn btn-ghost btn-sm text-error"
                id={"delete-api-key-#{key.id}"}
                aria-label={gettext("Delete API key")}
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </li>
          </ul>

          <.form for={@api_key_form} id="api-key-form" phx-submit="create_api_key" class="flex gap-2">
            <select name="valid_for" class="select w-48">
              <option value="30">{gettext("valid for 30 days")}</option>
              <option value="365" selected>{gettext("valid for 1 year")}</option>
            </select>
            <button class="btn" id="create-api-key">
              <.icon name="hero-plus" class="size-4" /> {gettext("Create API key")}
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
     |> assign(:page_title, gettext("Account"))
     |> assign(:passkey_error, nil)
     |> assign(:renaming, nil)
     |> assign(:rename_form, to_form(%{}))
     |> assign(:new_api_key, nil)
     |> assign(
       :profile_form,
       to_form(%{"display_name" => socket.assigns.current_user.display_name})
     )
     |> assign(:api_key_form, to_form(%{}))
     |> load_passkeys()
     |> load_api_keys()}
  end

  @impl true
  def handle_event("passkey_registered", _params, socket) do
    {:noreply,
     socket
     |> assign(:passkey_error, nil)
     |> put_flash(:info, gettext("Passkey added."))
     |> load_passkeys()}
  end

  def handle_event("passkey_failed", %{"error" => error}, socket) do
    {:noreply, assign(socket, :passkey_error, error)}
  end

  def handle_event("save_profile", %{"display_name" => name}, socket) do
    name = name |> String.trim() |> String.slice(0, 40)

    case Accounts.update_profile(actor(socket), blank_to_nil(name), actor: actor(socket)) do
      {:ok, user} ->
        {:noreply,
         socket
         |> assign(:current_user, user)
         |> assign(:profile_form, to_form(%{"display_name" => user.display_name}))
         |> put_flash(:info, gettext("Display name saved."))}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("The name could not be saved."))}
    end
  end

  # A full reload, so the layout and every later page use the new language
  def handle_event("save_locale", %{"locale" => locale}, socket) do
    user = actor(socket)

    case Accounts.update_profile(user, user.display_name, %{locale: blank_to_nil(locale)},
           actor: user
         ) do
      {:ok, user} ->
        Gettext.put_locale(PlattensammlungWeb.Gettext, user.locale || socket.assigns.locale)

        {:noreply,
         socket
         |> put_flash(:info, gettext("Language saved."))
         |> redirect(to: ~p"/account")}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("The language could not be saved."))}
    end
  end

  def handle_event("start_rename", %{"id" => id}, socket) do
    passkey = Enum.find(socket.assigns.passkeys, &(&1.id == id))

    {:noreply,
     socket
     |> assign(:renaming, id)
     |> assign(:rename_form, to_form(%{"name" => passkey.name}))}
  end

  def handle_event("cancel_rename", _params, socket) do
    {:noreply, assign(socket, :renaming, nil)}
  end

  def handle_event("rename_passkey", %{"passkey_id" => id, "name" => name}, socket) do
    passkey = Enum.find(socket.assigns.passkeys, &(&1.id == id))
    name = name |> String.trim() |> String.slice(0, 60)

    case Accounts.rename_passkey(passkey, blank_to_nil(name), actor: actor(socket)) do
      {:ok, _passkey} ->
        {:noreply, socket |> assign(:renaming, nil) |> load_passkeys()}

      {:error, _error} ->
        {:noreply, put_flash(socket, :error, gettext("The passkey could not be renamed."))}
    end
  end

  def handle_event("delete_passkey", %{"id" => id}, socket) do
    passkey = Enum.find(socket.assigns.passkeys, &(&1.id == id))
    Accounts.destroy_passkey!(passkey, actor: actor(socket))

    {:noreply, socket |> put_flash(:info, gettext("Passkey removed.")) |> load_passkeys()}
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

    {:noreply, socket |> put_flash(:info, gettext("API key deleted.")) |> load_api_keys()}
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

  defp blank_to_nil(""), do: nil
  defp blank_to_nil(value), do: value
end
