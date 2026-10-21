defmodule Plattensammlung.SoftAuthenticator do
  @moduledoc """
  A minimal software passkey for tests: creates an ES256 key pair and produces
  the same data a browser returns from `navigator.credentials.create/get`, so
  the real `wax_` verification runs in tests.
  """

  defstruct [:credential_id, :private_key, :x, :y, sign_count: 0]

  def new do
    {<<4, x::binary-size(32), y::binary-size(32)>>, private_key} =
      :crypto.generate_key(:ecdh, :secp256r1)

    %__MODULE__{
      credential_id: :crypto.strong_rand_bytes(16),
      private_key: private_key,
      x: x,
      y: y
    }
  end

  @doc "Answer to registration options (`navigator.credentials.create`)."
  def register(authenticator, options, origin) do
    rp_id = options["rp"]["id"]

    cose_key =
      CBOR.encode(%{
        1 => 2,
        3 => -7,
        -1 => 1,
        -2 => bytes(authenticator.x),
        -3 => bytes(authenticator.y)
      })

    attested_credential_data =
      <<0::128, byte_size(authenticator.credential_id)::16>> <>
        authenticator.credential_id <> cose_key

    # Flags: user present (0x01), user verified (0x04), attested credential data (0x40)
    auth_data = :crypto.hash(:sha256, rp_id) <> <<0x45, 0::32>> <> attested_credential_data

    attestation_object =
      CBOR.encode(%{"fmt" => "none", "attStmt" => %{}, "authData" => bytes(auth_data)})

    %{
      "rawId" => encode(authenticator.credential_id),
      "attestationObject" => encode(attestation_object),
      "clientDataJSON" => encode(client_data("webauthn.create", options["challenge"], origin))
    }
  end

  @doc "Answer to sign-in options (`navigator.credentials.get`)."
  def sign_in(authenticator, options, origin) do
    client_data_json = client_data("webauthn.get", options["challenge"], origin)
    auth_data = :crypto.hash(:sha256, options["rpId"]) <> <<0x05, authenticator.sign_count::32>>

    signature =
      :crypto.sign(
        :ecdsa,
        :sha256,
        auth_data <> :crypto.hash(:sha256, client_data_json),
        [authenticator.private_key, :secp256r1]
      )

    %{
      "rawId" => encode(authenticator.credential_id),
      "authenticatorData" => encode(auth_data),
      "clientDataJSON" => encode(client_data_json),
      "signature" => encode(signature)
    }
  end

  defp client_data(type, challenge, origin) do
    Phoenix.json_library().encode!(%{type: type, challenge: challenge, origin: origin})
  end

  defp bytes(binary), do: %CBOR.Tag{tag: :bytes, value: binary}
  defp encode(binary), do: Base.url_encode64(binary, padding: false)
end
