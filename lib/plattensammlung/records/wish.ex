defmodule Plattensammlung.Records.Wish do
  @moduledoc """
  "I'm looking for this album": one user's wishlist entry for a shared album
  (ADR 0016). At most one per user and album; adding it twice changes nothing.
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Records,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "wish"
    includes [:album]
    default_fields [:album_id, :owner_id]
  end

  postgres do
    table "wishes"
    repo Plattensammlung.Repo

    references do
      reference :album, on_delete: :delete
      # Deleting a user deletes their wishes
      reference :owner, on_delete: :delete
    end
  end

  actions do
    defaults [:read, :destroy]

    read :mine do
      description "The actor's wishes, optionally for one album"
      argument :album_id, :uuid

      filter expr(
               owner_id == ^actor(:id) and
                 (is_nil(^arg(:album_id)) or album_id == ^arg(:album_id))
             )
    end

    # Internal step of Album.merge (no policy allows it otherwise)
    update :move do
      accept [:album_id]
    end

    create :create do
      primary? true
      accept [:album_id]
      # The same wish again is not an error, it is simply kept
      upsert? true
      upsert_identity :unique_wish
      upsert_fields []

      change relate_actor(:owner)
    end
  end

  # Wishlists are visible to every signed-in user; only the owner removes a wish
  policies do
    policy action_type([:read, :create]) do
      access_type :strict
      authorize_if actor_present()
    end

    policy action_type(:destroy) do
      authorize_if expr(owner_id == ^actor(:id))
    end
  end

  attributes do
    uuid_v7_primary_key :id
    timestamps()
  end

  relationships do
    belongs_to :album, Plattensammlung.Records.Album do
      allow_nil? false
      public? true
    end

    belongs_to :owner, Plattensammlung.Accounts.User do
      allow_nil? false
      public? true
    end
  end

  identities do
    identity :unique_wish, [:owner_id, :album_id]
  end
end
