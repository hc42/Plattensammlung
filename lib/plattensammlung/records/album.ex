defmodule Plattensammlung.Records.Album do
  @moduledoc """
  An album, independent of a specific pressing (MusicBrainz release group,
  Discogs master). Owned when it has at least one copy; may also sit on the
  wishlist without any copy (see ADR 0006).
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Records,
    data_layer: AshPostgres.DataLayer,
    extensions: [AshJsonApi.Resource]

  json_api do
    type "album"
    # ?include=artist,copies
    includes [:artist, :copies]

    # Aggregates and calculations are only serialized when listed here
    default_fields [
      :title,
      :year,
      :cover_url,
      :genres,
      :wanted,
      :discogs_master_id,
      :musicbrainz_release_group_id,
      :owned,
      :copy_count,
      :discogs_url
    ]
  end

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

    defaults [:read]

    destroy :destroy do
      primary? true
      require_atomic? false

      change after_action(fn _changeset, album, _context ->
               Plattensammlung.Covers.delete(album.cover_url)
               {:ok, album}
             end)
    end

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
      change Plattensammlung.Records.Changes.StoreCover
      change manage_relationship(:copy, :copies, type: :create)
    end

    create :add_to_wishlist do
      description "Adds an album without a copy, marked as wanted."
      accept @fields

      argument :artist_name, :ci_string, allow_nil?: false

      change set_attribute(:wanted, true)
      change {Plattensammlung.Records.Changes.FindOrCreateArtist, []}
      change Plattensammlung.Records.Changes.StoreCover
    end

    update :update do
      accept @fields ++ [:wanted]
      argument :artist_name, :ci_string
      require_atomic? false

      change {Plattensammlung.Records.Changes.FindOrCreateArtist, []}
      change Plattensammlung.Records.Changes.StoreCover
    end

    update :mark_wanted do
      # Deliberately not atomic: AshJsonApi tries an atomic UPDATE first, and that
      # fails when the response loads the owned/copy_count aggregates. A function
      # change cannot run atomically, so Ash reads the record and updates it.
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :wanted, true)
      end
    end

    update :unmark_wanted do
      # Deliberately not atomic: AshJsonApi tries an atomic UPDATE first, and that
      # fails when the response loads the owned/copy_count aggregates. A function
      # change cannot run atomically, so Ash reads the record and updates it.
      require_atomic? false

      change fn changeset, _context ->
        Ash.Changeset.change_attribute(changeset, :wanted, false)
      end
    end

    read :search do
      description """
      Albums whose title or artist contains the query (case-insensitive),
      optionally limited to the collection (owned) or the wishlist.
      """

      argument :query, :ci_string

      argument :status, :atom do
        constraints one_of: [:collection, :wishlist]
      end

      filter expr(
               is_nil(^arg(:query)) or contains(title, ^arg(:query)) or
                 contains(artist.name, ^arg(:query))
             )

      filter expr(
               is_nil(^arg(:status)) or
                 (^arg(:status) == :collection and exists(copies, true)) or
                 (^arg(:status) == :wishlist and wanted == true)
             )

      prepare build(sort: [title: :asc], load: [:artist])
    end

    read :by_barcode do
      description "Albums that have a copy with this barcode."
      argument :barcode, :string, allow_nil?: false
      filter expr(exists(copies, barcode == ^arg(:barcode)))
    end

    action :lookup, {:array, Plattensammlung.Records.LookupResult} do
      description """
      Searches Discogs and MusicBrainz by barcode or by artist and title.
      A generic action: it runs custom code instead of reading or writing rows.
      """

      argument :query, :string, allow_nil?: false

      run fn input, _context ->
        Plattensammlung.Lookup.search(input.arguments.query)
      end
    end

    read :duplicates do
      description "Albums with exactly this artist and title (case-insensitive)."
      argument :artist_name, :ci_string, allow_nil?: false
      argument :title, :ci_string, allow_nil?: false

      filter expr(title == ^arg(:title) and artist.name == ^arg(:artist_name))
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
