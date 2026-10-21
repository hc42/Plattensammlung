defmodule Plattensammlung.Records.Album do
  @moduledoc """
  An album, independent of a specific pressing (MusicBrainz release group,
  Discogs master). Owned when it has at least one copy; may also sit on the
  wishlist without any copy (see ADR 0006).
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Records,
    data_layer: AshPostgres.DataLayer

  postgres do
    table "albums"
    repo Plattensammlung.Repo

    references do
      # An artist with albums cannot be deleted
      reference :artist, on_delete: :restrict
    end
  end

  actions do
    @fields [
      :title,
      :year,
      :cover_url,
      :genres,
      :discogs_master_id,
      :musicbrainz_release_group_id
    ]

    defaults [:read, :destroy]

    create :add_to_collection do
      description "Adds an album together with one owned copy."
      accept @fields

      argument :artist_name, :ci_string, allow_nil?: false

      argument :copy, :map do
        description "Optional pressing details for the copy"
        default %{}
      end

      change set_attribute(:wanted, false)
      change {Plattensammlung.Records.Changes.FindOrCreateArtist, []}
      change manage_relationship(:copy, :copies, type: :create)
    end

    create :add_to_wishlist do
      description "Adds an album without a copy, marked as wanted."
      accept @fields

      argument :artist_name, :ci_string, allow_nil?: false

      change set_attribute(:wanted, true)
      change {Plattensammlung.Records.Changes.FindOrCreateArtist, []}
    end

    update :update do
      accept @fields ++ [:wanted]
      argument :artist_name, :ci_string
      require_atomic? false

      change {Plattensammlung.Records.Changes.FindOrCreateArtist, []}
    end

    update :mark_wanted do
      change set_attribute(:wanted, true)
    end

    update :unmark_wanted do
      change set_attribute(:wanted, false)
    end

    read :search do
      description "Albums whose title or artist contains the query (case-insensitive)."
      argument :query, :ci_string

      filter expr(
               is_nil(^arg(:query)) or contains(title, ^arg(:query)) or
                 contains(artist.name, ^arg(:query))
             )

      prepare build(sort: [title: :asc], load: [:artist])
    end

    read :collection do
      filter expr(exists(copies, true))
      prepare build(sort: [title: :asc], load: [:artist])
    end

    read :wishlist do
      filter expr(wanted == true)
      prepare build(sort: [title: :asc], load: [:artist])
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :title, :ci_string do
      allow_nil? false
      public? true
    end

    attribute :year, :integer do
      description "Year of the original release"
      constraints min: 1900, max: 2100
      public? true
    end

    attribute :cover_url, :string, public?: true

    attribute :genres, {:array, :string} do
      default []
      allow_nil? false
      public? true
    end

    attribute :wanted, :boolean do
      description "On the wishlist"
      default false
      allow_nil? false
      public? true
    end

    attribute :discogs_master_id, :integer, public?: true
    attribute :musicbrainz_release_group_id, :uuid, public?: true

    timestamps()
  end

  relationships do
    belongs_to :artist, Plattensammlung.Records.Artist do
      allow_nil? false
      public? true
    end

    has_many :copies, Plattensammlung.Records.Copy do
      public? true
    end
  end

  calculations do
    calculate :discogs_url,
              :string,
              expr(
                if is_nil(discogs_master_id) do
                  nil
                else
                  "https://www.discogs.com/master/" <> type(discogs_master_id, :string)
                end
              ),
              public?: true
  end

  aggregates do
    # Computed by the database on demand, never stored
    count :copy_count, :copies, public?: true
    exists :owned, :copies, public?: true
  end
end
