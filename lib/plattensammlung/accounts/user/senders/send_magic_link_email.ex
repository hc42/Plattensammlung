defmodule Plattensammlung.Accounts.User.Senders.SendMagicLinkEmail do
  @moduledoc """
  Sends the magic link e-mail. Only addresses in `ALLOWED_EMAILS` get one; for
  others nothing is sent (and the sign-in page does not reveal which is which).

  The link points to the host the user signed in from (passed as `base_url` in
  the action context), so it also works from a phone via https://….local:4001.
  """
  use AshAuthentication.Sender
  use PlattensammlungWeb, :verified_routes

  import Swoosh.Email

  alias Plattensammlung.{Accounts, Mailer}

  require Logger

  @impl true
  def send(user_or_email, token, opts) do
    email =
      case user_or_email do
        %{email: email} -> to_string(email)
        email -> to_string(email)
      end

    if Accounts.allowed_email?(email) do
      link = base_url(opts) <> ~p"/magic_link/#{token}"

      new()
      |> from(
        Application.get_env(
          :plattensammlung,
          :mail_from,
          {"Plattensammlung", "noreply@plattensammlung.local"}
        )
      )
      |> to(email)
      |> subject("Dein Anmeldelink für die Plattensammlung")
      |> html_body("""
      <p>Hallo!</p>
      <p>Mit diesem Link meldest du dich bei deiner Plattensammlung an:</p>
      <p><a href="#{link}">#{link}</a></p>
      <p>Der Link ist 10 Minuten gültig. Wenn du ihn nicht angefordert hast, ignoriere diese E-Mail.</p>
      """)
      |> text_body("Mit diesem Link meldest du dich an (10 Minuten gültig): #{link}")
      |> deliver()
    else
      Logger.warning("Magic link requested for an address not in ALLOWED_EMAILS")
    end

    :ok
  end

  # A failing mail server must not break the sign-in page; the reason is logged
  defp deliver(email) do
    case Mailer.deliver(email) do
      {:ok, _metadata} -> :ok
      {:error, reason} -> Logger.error("Magic link e-mail could not be sent: #{inspect(reason)}")
    end
  end

  defp base_url(opts) do
    case opts[:source_context] do
      %{base_url: "http" <> _ = base_url} -> base_url
      _ -> PlattensammlungWeb.Endpoint.url()
    end
  end
end
