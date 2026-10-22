defmodule PlattensammlungWeb.SignInLive do
  @moduledoc """
  Sign-in with a passkey or, as fallback, a magic link by e-mail (ADR 0005).
  """
  use PlattensammlungWeb, :live_view

  alias Plattensammlung.Accounts

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="mx-auto max-w-sm space-y-8 pt-8">
        <div class="space-y-1 text-center">
          <h1 class="text-2xl font-bold">Anmelden</h1>
          <p class="text-sm opacity-70">Deine Plattensammlung wartet.</p>
        </div>

        <div class="space-y-2">
          <button
            id="passkey-sign-in"
            phx-hook="PasskeySignIn"
            data-status="#passkey-status"
            class="btn btn-primary btn-block"
          >
            <.icon name="hero-finger-print" class="size-5" /> Mit Passkey anmelden
          </button>
          <p id="passkey-status" class="min-h-5 text-center text-sm text-error" aria-live="polite">
          </p>
        </div>

        <div class="divider text-xs opacity-60">oder per E-Mail</div>

        <%= if @requested_for do %>
          <div id="magic-link-sent" class="alert alert-info alert-soft text-sm">
            <.icon name="hero-envelope" class="size-5" />
            <span>
              Wenn {@requested_for} freigeschaltet ist, kommt gleich ein Anmeldelink.
              <.link :if={@dev_mailbox?} href="/dev/mailbox" target="_blank" class="link">
                Postfach (Entwicklung) öffnen
              </.link>
            </span>
          </div>
        <% else %>
          <.form for={@form} id="magic-link-form" phx-submit="request_link">
            <.input
              field={@form[:email]}
              type="email"
              label="E-Mail-Adresse"
              autocomplete="username"
              required
            />
            <.button class="btn btn-block mt-2" phx-disable-with="Wird gesendet …">
              Anmeldelink senden
            </.button>
          </.form>
        <% end %>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Anmelden")
     |> assign(:form, to_form(%{"email" => ""}))
     |> assign(:requested_for, nil)
     # Only available while mounting; used for the rate limit of magic links
     |> assign(:client_ip, PlattensammlungWeb.ClientIp.from_socket(socket))
     |> assign(:dev_mailbox?, Application.get_env(:plattensammlung, :dev_routes, false))}
  end

  @impl true
  def handle_event("request_link", %{"email" => email}, socket) do
    # The answer is the same whether the address exists or not
    base_url = PlattensammlungWeb.PublicUrl.base_url(socket.host_uri)

    Accounts.request_magic_link(email,
      context: %{base_url: base_url, client_ip: socket.assigns.client_ip}
    )

    {:noreply, assign(socket, :requested_for, String.trim(email))}
  end
end
