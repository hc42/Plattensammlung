defmodule Plattensammlung.Records.Artist do
  @moduledoc """
  An artist or band. Albums reference exactly one artist; collaborations and
  compilations use a combined name such as "Various Artists" (see ADR 0006).
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Records,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "artists"
    repo Plattensammlung.Repo
  end

  actions do
    @fields [:name, :sort_name, :discogs_id, :musicbrainz_id]

    defaults [:read, :destroy, create: @fields, update: @fields]
  end

  attributes do
    uuid_v7_primary_key :id

    # :ci_string is case-insensitive (Postgres citext): "the beatles" == "The Beatles"
    attribute :name, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :sort_name, :string do
      description "Name used for sorting, e.g. \"Beatles, The\""
      public? true
    end

    attribute :discogs_id, :integer, public?: true
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
