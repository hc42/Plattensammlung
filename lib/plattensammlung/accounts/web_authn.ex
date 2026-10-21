defmodule Plattensammlung.Accounts.WebAuthn do
  @moduledoc """
  Passkey registration and sign-in with the `wax_` library (see ADR 0005).

  Both flows have two steps:

  1. `*_options/…` creates a challenge. The caller keeps the `Wax.Challenge`
     (in the session) and sends the options to the browser, which passes them
     to `navigator.credentials.create/get`.
  2. `register/3` / `authenticate/2` verify the browser's answer against that
     challenge.

  Binary values travel as base64url strings between browser and server.
  Passkeys are bound to the host name: one created on `localhost` does not work
  on `….local` and vice versa.
  """
  alias Plattensammlung.Accounts

  # Challenges are valid for two minutes
  @timeout_seconds 120

  @doc "Challenge and `navigator.credentials.create` options for a signed-in user."
  def registration_options(user, origin) do
    challenge =
      Wax.new_registration_challenge(
        origin: origin,
        rp_id: :auto,
        attestation: "none",
        user_verification: "preferred",
        timeout: @timeout_seconds
      )

    existing = Accounts.list_passkeys!(actor: user)

    options = %{
      challenge: encode(challenge.bytes),
      rp: %{id: challenge.rp_id, name: "Plattensammlung"},
      user: %{
        id: encode(Ecto.UUID.dump!(user.id)),
        name: to_string(user.email),
        displayName: to_string(user.email)
      },
      # ES256 and RS256, supported by all current authenticators
      pubKeyCredParams: [%{type: "public-key", alg: -7}, %{type: "public-key", alg: -257}],
      authenticatorSelection: %{residentKey: "required", userVerification: "preferred"},
      excludeCredentials:
        Enum.map(existing, &%{type: "public-key", id: encode(&1.credential_id)}),
      attestation: "none",
      timeout: @timeout_seconds * 1000
    }

    {challenge, options}
  end

  @doc "Verifies a new credential and stores it as a passkey of `user`."
  def register(user, challenge, params) do
    with {:ok, attestation_object} <- decode(params["attestationObject"]),
         {:ok, client_data_json} <- decode(params["clientDataJSON"]),
         {:ok, {authenticator_data, _attestation}} <-
           Wax.register(attestation_object, client_data_json, challenge) do
      credential = authenticator_data.attested_credential_data

      Accounts.register_passkey(
        %{
          name: params["name"] |> to_string() |> String.trim() |> String.slice(0, 60),
          credential_id: credential.credential_id,
          public_key: :erlang.term_to_binary(credential.credential_public_key),
          sign_count: authenticator_data.sign_count
        },
        actor: user
      )
    end
  end

  @doc "Challenge and `navigator.credentials.get` options for signing in."
  def authentication_options(origin) do
    challenge =
      Wax.new_authentication_challenge(
        origin: origin,
        rp_id: :auto,
        user_verification: "preferred",
        timeout: @timeout_seconds
      )

    # No allowCredentials: the browser offers all passkeys for this site
    options = %{
      challenge: encode(challenge.bytes),
      rpId: challenge.rp_id,
      userVerification: "preferred",
      timeout: @timeout_seconds * 1000
    }

    {challenge, options}
  end

  @doc "Verifies a sign-in assertion and returns the user."
  def authenticate(challenge, params) do
    with {:ok, credential_id} <- decode(params["rawId"]),
         {:ok, authenticator_data} <- decode(params["authenticatorData"]),
         {:ok, signature} <- decode(params["signature"]),
         {:ok, client_data_json} <- decode(params["clientDataJSON"]),
         # Nobody is signed in yet, so these two calls skip authorization
         {:ok, passkey} <- Accounts.get_passkey_by_credential_id(credential_id, authorize?: false),
         public_key = :erlang.binary_to_term(passkey.public_key, [:safe]),
         {:ok, auth_data} <-
           Wax.authenticate(
             credential_id,
             authenticator_data,
             signature,
             client_data_json,
             challenge,
             [{credential_id, public_key}]
           ),
         :ok <- check_sign_count(passkey, auth_data.sign_count),
         true <- Accounts.allowed_email?(passkey.user.email) || {:error, :email_not_allowed},
         {:ok, _passkey} <-
           Accounts.record_passkey_use(passkey, auth_data.sign_count, authorize?: false) do
      {:ok, passkey.user}
    end
  end

  # Authenticators that count signatures must count up; otherwise the key may
  # have been cloned. Many passkeys always report 0, which is fine.
  defp check_sign_count(%{sign_count: stored}, new) when stored > 0 and new <= stored,
    do: {:error, :sign_count_not_increased}

  defp check_sign_count(_passkey, _new), do: :ok

  defp encode(binary), do: Base.url_encode64(binary, padding: false)

  defp decode(value) when is_binary(value) do
    case Base.url_decode64(value, padding: false) do
      {:ok, binary} -> {:ok, binary}
      :error -> {:error, :invalid_encoding}
    end
  end

  defp decode(_value), do: {:error, :missing_value}
end
