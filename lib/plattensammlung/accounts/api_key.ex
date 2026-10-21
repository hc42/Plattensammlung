defmodule Plattensammlung.Accounts.ApiKey do
  @moduledoc """
  A key for API clients (`Authorization: Bearer <key>`). Only a hash is stored;
  the plain key is returned once, as `plaintext_api_key` metadata, on create.
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  postgres do
    table "api_keys"
    repo Plattensammlung.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      primary? true
      accept [:expires_at]
      change relate_actor(:user)

      change {AshAuthentication.Strategy.ApiKey.GenerateApiKey,
              prefix: :plattensammlung, hash: :api_key_hash}
    end
  end

  policies do
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # Users manage only their own keys
    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action_type([:read, :destroy]) do
      authorize_if relates_to_actor_via(:user)
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :api_key_hash, :binary do
      allow_nil? false
      sensitive? true
    end

    attribute :expires_at, :utc_datetime_usec do
      allow_nil? false
      public? true
    end

    create_timestamp :inserted_at, public?: true
  end

  relationships do
    belongs_to :user, Plattensammlung.Accounts.User
  end

  calculations do
    calculate :valid, :boolean, expr(expires_at > now())
  end

  identities do
    identity :unique_api_key, [:api_key_hash]
  end
end
