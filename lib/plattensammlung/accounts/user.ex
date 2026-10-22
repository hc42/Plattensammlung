defmodule Plattensammlung.Accounts.User do
  @moduledoc """
  A person who may use the collection. Signs in with a magic link, a passkey
  or (for the API) an API key; only addresses in `ALLOWED_EMAILS` are accepted.
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Accounts,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshAuthentication]

  authentication do
    add_ons do
      log_out_everywhere do
        apply_on_password_change? true
      end
    end

    tokens do
      enabled? true
      token_resource Plattensammlung.Accounts.Token
      signing_secret Plattensammlung.Secrets
      store_all_tokens? true
      require_token_presence_for_authentication? true
    end

    strategies do
      magic_link do
        identity_field :email
        registration_enabled? true
        require_interaction? true

        sender Plattensammlung.Accounts.User.Senders.SendMagicLinkEmail
      end

      remember_me :remember_me

      api_key :api_key do
        api_key_relationship :valid_api_keys
        api_key_hash_attribute :api_key_hash
      end
    end
  end

  postgres do
    table "users"
    repo Plattensammlung.Repo
  end

  actions do
    defaults [:read]

    read :collectors do
      description "Other users as others may see them: id and display name only, never the e-mail."
      prepare build(select: [:id, :display_name], sort: [display_name: :asc])
    end

    update :update_profile do
      accept [:display_name]
    end

    read :get_by_subject do
      description "Get a user by the subject claim in a JWT"
      argument :subject, :string, allow_nil?: false
      get? true
      prepare AshAuthentication.Preparations.FilterBySubject
    end

    read :get_by_email do
      description "Looks up a user by their email"
      get_by :email
    end

    create :sign_in_with_magic_link do
      description "Sign in or register a user with magic link."

      argument :token, :string do
        description "The token from the magic link that was sent to the user"
        allow_nil? false
      end

      argument :remember_me, :boolean do
        description "Whether to generate a remember me token"
        allow_nil? true
      end

      upsert? true
      upsert_identity :unique_email
      upsert_fields [:email]

      # Uses the information from the token to create or sign in the user
      change AshAuthentication.Strategy.MagicLink.SignInChange

      # Runs after the change above has taken the e-mail address from the token
      validate Plattensammlung.Accounts.Validations.AllowedEmail

      change {AshAuthentication.Strategy.RememberMe.MaybeGenerateTokenChange,
              strategy_name: :remember_me}

      metadata :token, :string do
        allow_nil? false
      end
    end

    action :request_magic_link do
      argument :email, :ci_string do
        allow_nil? false
      end

      run AshAuthentication.Strategy.MagicLink.Request
    end

    read :sign_in_with_api_key do
      argument :api_key, :string, allow_nil?: false
      prepare AshAuthentication.Strategy.ApiKey.SignInPreparation
    end
  end

  policies do
    # Sign-in flows run with a special context set by AshAuthentication
    bypass AshAuthentication.Checks.AshAuthenticationInteraction do
      authorize_if always()
    end

    # Anyone may ask for a link; the sender only mails allowed addresses
    policy action(:request_magic_link) do
      authorize_if always()
    end

    # The full record (with e-mail) only for oneself
    policy action(:read) do
      authorize_if expr(id == ^actor(:id))
    end

    # Name list for the "Sammler" page, visible to every signed-in user
    policy action(:collectors) do
      authorize_if actor_present()
    end

    policy action(:update_profile) do
      authorize_if expr(id == ^actor(:id))
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :email, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :display_name, :string do
      description "Name other users see (the e-mail stays private)"
      constraints max_length: 40
      public? true
    end
  end

  relationships do
    has_many :valid_api_keys, Plattensammlung.Accounts.ApiKey do
      filter expr(valid)
    end

    has_many :passkeys, Plattensammlung.Accounts.Passkey

    has_many :copies, Plattensammlung.Records.Copy do
      destination_attribute :owner_id
    end

    has_many :wishes, Plattensammlung.Records.Wish do
      destination_attribute :owner_id
    end
  end

  identities do
    identity :unique_email, [:email]
  end
end
