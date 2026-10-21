defmodule PlattensammlungWeb.AuthOverrides do
  @moduledoc """
  Texts and styles for the AshAuthentication.Phoenix page that opens when the
  magic link from the e-mail is clicked. Combined with the DaisyUI overrides.
  See https://hexdocs.pm/ash_authentication_phoenix/ui-overrides.html
  """
  use AshAuthentication.Phoenix.Overrides

  alias AshAuthentication.Phoenix.Components

  override Components.MagicLink.SignIn do
    set :show_banner, false
  end

  override Components.MagicLink.Input do
    set :submit_label, "Jetzt anmelden"
    set :remember_me_input_label, "Angemeldet bleiben"
  end

  override Components.MagicLink do
    set :disable_button_text, "Anmelden …"
  end
end
