defmodule Plattensammlung.Accounts.Passkey do
  @moduledoc """
  A WebAuthn credential ("passkey") of a user (see ADR 0005). The browser keeps
  the private key; we store the credential id and the public key (a COSE key,
  serialized with `:erlang.term_to_binary/1`) to verify sign-in signatures.
  The WebAuthn protocol itself lives in `Plattensammlung.Accounts.WebAuthn`.
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "passkeys"
    repo Plattensammlung.Repo

    references do
      reference :user, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    create :register do
      accept [:name, :credential_id, :public_key, :sign_count]
      change relate_actor(:user)
    end

    read :by_credential_id do
      description "Used during sign-in, before anyone is signed in."
      argument :credential_id, :binary, allow_nil?: false
      get? true
      filter expr(credential_id == ^arg(:credential_id))
      prepare build(load: [:user])
    end

    update :rename do
      accept [:name]
    end

    update :record_use do
      argument :sign_count, :integer, allow_nil?: false
      require_atomic? false

      change set_attribute(:sign_count, arg(:sign_count))
      change set_attribute(:last_used_at, &DateTime.utc_now/0)
    end
  end

  policies do
    # Without an actor, :by_credential_id finds nothing (read policy below) and
    # :record_use is forbidden (no policy). Plattensammlung.Accounts.WebAuthn
    # calls both with authorize?: false during sign-in, before anyone is signed in.

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:read, :destroy]) do
      authorize_if relates_to_actor_via(:user)
    end

    policy action(:rename) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :credential_id, :binary do
      allow_nil? false
    end

    attribute :public_key, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :sign_count, :integer do
      default 0
      allow_nil? false
    end

    attribute :name, :string do
      description "Shown on the account page, e.g. \"iPhone\""
      constraints max_length: 60
      public? true
    end

    attribute :last_used_at, :utc_datetime_usec, public?: true

    timestamps public?: true
  end

  relationships do
    belongs_to :user, Plattensammlung.Accounts.User do
      allow_nil? false
    end
  end

  identities do
    identity :unique_credential_id, [:credential_id]
  end
end
