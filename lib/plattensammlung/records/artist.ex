defmodule Plattensammlung.Records.Artist do
  @moduledoc """
  An artist or band. Albums reference exactly one artist; collaborations and
  compilations use a combined name such as "Various Artists" (see ADR 0006).
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Records,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "artist"
    includes [:albums]
  end

  postgres do
    table "artists"
    repo Plattensammlung.Repo
  end

  actions do
    @fields [:name, :sort_name, :discogs_id, :musicbrainz_id]

    defaults [:read, :destroy, create: @fields, update: @fields]
  end

  policies do
    # One shared collection: every signed-in user (or API key) may do everything
    policy always() do
      # :strict raises Forbidden instead of silently returning no rows
      access_type :strict
      authorize_if actor_present()
    end
  end

  attributes do
    uuid_v7_primary_key :id

    # :ci_string is case-insensitive (Postgres citext): "the beatles" == "The Beatles"
    attribute :name, :ci_string do
      allow_nil? false
      constraints max_length: 200
      public? true
    end

    attribute :sort_name, :string do
      constraints max_length: 200
      description "Name used for sorting, e.g. \"Beatles, The\""
      public? true
    end

    attribute :discogs_id, :integer, constraints: [min: 1], public?: true
    attribute :musicbrainz_id, :uuid, public?: true

    timestamps()
  end

  relationships do
    has_many :albums, Plattensammlung.Records.Album do
      public? true
    end
  end

  identities do
    # Creates a unique index and lets actions look up artists by name
    identity :unique_name, [:name]
  end
end
