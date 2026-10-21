defmodule Plattensammlung.Accounts do
  @moduledoc """
  Users and sign-in: magic link (e-mail), passkeys and API keys (see ADR 0005).
  Only e-mail addresses in the `:allowed_emails` config (`ALLOWED_EMAILS`) can
  sign in.
  """
  use Ash.Domain, otp_app: :plattensammlung

  resources do
    resource Plattensammlung.Accounts.Token

    resource Plattensammlung.Accounts.User do
      define :request_magic_link, args: [:email]
      define :get_user, action: :read, get_by: [:id]
    end

    resource Plattensammlung.Accounts.ApiKey do
      define :create_api_key, action: :create, args: [:expires_at]
      define :list_api_keys, action: :read
      define :destroy_api_key, action: :destroy
    end

    resource Plattensammlung.Accounts.Passkey do
      define :register_passkey, action: :register
      define :list_passkeys, action: :read
      define :get_passkey_by_credential_id, action: :by_credential_id, args: [:credential_id]
      define :record_passkey_use, action: :record_use, args: [:sign_count]
      define :destroy_passkey, action: :destroy
    end
  end

  @doc "Whether this e-mail address may sign in (case-insensitive)."
  def allowed_email?(nil), do: false

  def allowed_email?(email) do
    normalized = email |> to_string() |> String.trim() |> String.downcase()
    normalized in Application.get_env(:plattensammlung, :allowed_emails, [])
  end
end
