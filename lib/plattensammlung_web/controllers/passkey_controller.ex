defmodule PlattensammlungWeb.PasskeyController do
  @moduledoc """
  JSON endpoints for the passkey JavaScript (`assets/js/hooks/passkey.js`).
  The WebAuthn challenge is kept in the session between the two requests of a
  flow and removed when it is used, so every challenge works only once.
  """
  use PlattensammlungWeb, :controller

  alias Plattensammlung.Accounts.WebAuthn

  require Logger

  @challenge_key :webauthn_challenge

  def sign_in_options(conn, _params) do
    {challenge, options} = WebAuthn.authentication_options(origin(conn))

    conn
    |> put_session(@challenge_key, challenge)
    |> json(options)
  end

  def sign_in(conn, params) do
    {challenge, conn} = pop_challenge(conn)

    with %Wax.Challenge{} <- challenge,
         {:ok, user} <- WebAuthn.authenticate(challenge, params),
         {:ok, user} <- with_session_token(user) do
      conn
      |> AshAuthentication.Plug.Helpers.store_in_session(user)
      |> put_flash(:info, "Angemeldet.")
      |> json(%{redirect_to: get_session(conn, :return_to) || ~p"/"})
    else
      error ->
        Logger.info("Passkey sign-in failed: #{inspect(error)}")

        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Anmeldung mit diesem Passkey nicht möglich."})
    end
  end

  def register_options(conn, _params) do
    case conn.assigns[:current_user] do
      nil ->
        conn |> put_status(:unauthorized) |> json(%{error: "Bitte zuerst anmelden."})

      user ->
        {challenge, options} = WebAuthn.registration_options(user, origin(conn))

        conn
        |> put_session(@challenge_key, challenge)
        |> json(options)
    end
  end

  def register(conn, params) do
    {challenge, conn} = pop_challenge(conn)

    with %{} = user <- conn.assigns[:current_user],
         %Wax.Challenge{} <- challenge,
         {:ok, passkey} <- WebAuthn.register(user, challenge, params) do
      json(conn, %{id: passkey.id})
    else
      error ->
        Logger.info("Passkey registration failed: #{inspect(error)}")

        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: "Der Passkey konnte nicht gespeichert werden."})
    end
  end

  defp pop_challenge(conn) do
    {get_session(conn, @challenge_key), delete_session(conn, @challenge_key)}
  end

  # The page's own origin, so passkeys work on localhost and on <name>.local
  defp origin(conn) do
    port =
      case {conn.scheme, conn.port} do
        {:http, 80} -> ""
        {:https, 443} -> ""
        {_scheme, port} -> ":#{port}"
      end

    "#{conn.scheme}://#{conn.host}#{port}"
  end

  # The session stores a JWT that AshAuthentication also records in the token
  # table (require_token_presence_for_authentication?), like the other strategies
  defp with_session_token(user) do
    case AshAuthentication.Jwt.token_for_user(user) do
      {:ok, token, _claims} -> {:ok, Ash.Resource.put_metadata(user, :token, token)}
      error -> error
    end
  end
end
