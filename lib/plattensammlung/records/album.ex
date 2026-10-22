defmodule Plattensammlung.Records.Album do
  @moduledoc """
  An album, independent of a specific pressing (MusicBrainz release group,
  Discogs master). Albums are shared by all users (ADR 0016): each user adds
  own copies (`Copy`) or a wish (`Wish`). `owned`, `copy_count` and `wanted`
  describe the actor's own copies and wish (see ADR 0006).
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Records,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "album"
    # ?include=artist,copies
    includes [:artist, :copies]

    # Aggregates and calculations are only serialized when listed here. `id`
    # is listed for the generic add actions, whose plain JSON answer has no
    # JSON:API envelope with an id
    default_fields [
      :id,
      :title,
      :year,
      :cover_url,
      :genres,
      :wanted,
      :discogs_master_id,
      :musicbrainz_release_group_id,
      :owned,
      :copy_count,
      :discogs_url,
      :spotify_album_id,
      :tidal_album_id,
      :spotify_url,
      :tidal_url
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
      :musicbrainz_release_group_id,
      :spotify_album_id,
      :tidal_album_id
    ]

    defaults [:read]

    create :create do
      description "Creates a catalog entry; normally used through add_to_collection/add_to_wishlist."
      primary? true
      accept @fields

      argument :artist_name, :ci_string, allow_nil?: false, constraints: [max_length: 200]

      validate Plattensammlung.Records.Validations.CoverSource
      change {Plattensammlung.Records.Changes.FindOrCreateArtist, []}
      change Plattensammlung.Records.Changes.StoreCover
      change Plattensammlung.Records.Changes.NormalizeStreamingIds
      change Plattensammlung.Records.Changes.FillStreamingLinks
    end

    # Generic actions: they reuse an album that is already in the catalog
    # (same Discogs/MusicBrainz id, or same artist and title) instead of
    # creating a second one, then add the actor's copy or wish (ADR 0016)
    action :add_to_collection, :struct do
      description "Adds an album (reusing an existing one) together with an own copy."
      constraints instance_of: __MODULE__
      # No surrounding transaction: cover download and link lookup happen before
      # the album's own transaction and must not hold a database connection

      argument :artist_name, :ci_string, allow_nil?: false, constraints: [max_length: 200]
      argument :title, :ci_string, allow_nil?: false, constraints: [max_length: 200]
      argument :year, :integer
      argument :cover_url, :string
      argument :genres, {:array, :string}
      argument :discogs_master_id, :integer
      argument :musicbrainz_release_group_id, :uuid
      argument :spotify_album_id, :string
      argument :tidal_album_id, :string

      argument :copy, :map do
        description "Optional pressing details for the copy"
        default %{}
      end

      run {Plattensammlung.Records.AddAlbum, to: :collection}
    end

    action :add_to_wishlist, :struct do
      description "Puts an album (reusing an existing one) on the actor's wishlist."
      constraints instance_of: __MODULE__
      # No surrounding transaction: cover download and link lookup happen before
      # the album's own transaction and must not hold a database connection

      argument :artist_name, :ci_string, allow_nil?: false, constraints: [max_length: 200]
      argument :title, :ci_string, allow_nil?: false, constraints: [max_length: 200]
      argument :year, :integer
      argument :cover_url, :string
      argument :genres, {:array, :string}
      argument :discogs_master_id, :integer
      argument :musicbrainz_release_group_id, :uuid
      argument :spotify_album_id, :string
      argument :tidal_album_id, :string

      run {Plattensammlung.Records.AddAlbum, to: :wishlist}
    end

    action :remove do
      description """
      Removes the album from the actor's collection and wishlist (own copies and
      wish). The album itself is deleted once no one has it any more.
      """

      argument :album_id, :uuid, allow_nil?: false
      # No surrounding transaction: the cover file is deleted only after the
      # album's own delete is committed
      run Plattensammlung.Records.RemoveAlbum
    end

    destroy :destroy do
      description "Deletes an album no one has in collection or wishlist."
      primary? true
      require_atomic? false

      # Only once the delete is committed, so a rollback keeps the cover
      change fn changeset, _context ->
        Ash.Changeset.after_transaction(changeset, fn
          _changeset, {:ok, album} = result ->
            Plattensammlung.Covers.delete(album.cover_url)
            result

          _changeset, error ->
            error
        end)
      end

      change Plattensammlung.Records.Changes.RemoveOrphanedArtist
    end

    update :update do
      description "Changes the shared album data; `wanted` sets the actor's wish."
      accept @fields
      argument :artist_name, :ci_string, constraints: [max_length: 200]
      argument :wanted, :boolean, description: "On the actor's wishlist"
      require_atomic? false
      validate Plattensammlung.Records.Validations.CoverSource

      change {Plattensammlung.Records.Changes.FindOrCreateArtist, []}
      change Plattensammlung.Records.Changes.RemoveOrphanedArtist
      change Plattensammlung.Records.Changes.StoreCover
      change Plattensammlung.Records.Changes.NormalizeStreamingIds
      # Plain edits stay offline; a new Discogs/MusicBrainz link triggers the lookup
      change {Plattensammlung.Records.Changes.FillStreamingLinks, when: :links_changed}
      change Plattensammlung.Records.Changes.SetWanted
    end

    update :complete do
      description "Fills only the still empty fields, e.g. when an import reuses an album."
      accept @fields
      require_atomic? false
      validate Plattensammlung.Records.Validations.CoverSource

      # First: drop values for fields that already have one
      change Plattensammlung.Records.Changes.KeepExistingValues
      change Plattensammlung.Records.Changes.StoreCover
      change Plattensammlung.Records.Changes.NormalizeStreamingIds
      change {Plattensammlung.Records.Changes.FillStreamingLinks, when: :links_changed}
    end

    # Deliberately not atomic: SetWanted works with hooks (and AshJsonApi tries
    # an atomic UPDATE first, which fails when the response loads calculations)
    update :mark_wanted do
      require_atomic? false
      change {Plattensammlung.Records.Changes.SetWanted, wanted: true}
    end

    update :unmark_wanted do
      require_atomic? false
      change {Plattensammlung.Records.Changes.SetWanted, wanted: false}
    end

    read :search do
      description """
      Albums whose title or artist contains the query (case-insensitive). With a
      status only one user's collection, wishlist or the rest (`owner_id`,
      default: the actor); without one the whole shared catalog. Filters by
      genre, decade, artist or condition (see AlbumFilters).
      """

      argument :owner_id, :uuid, description: "Whose collection/wishlist (default: the actor's)"
      argument :query, :ci_string, constraints: [max_length: 200]
      argument :genre, :string, constraints: [max_length: 200]
      argument :decade, :string, constraints: [max_length: 200]
      argument :artist, :ci_string, constraints: [max_length: 200]
      argument :condition, :string, constraints: [max_length: 200]

      argument :status, :atom do
        # :other = neither in the user's collection nor on their wishlist
        constraints one_of: [:collection, :wishlist, :other]
      end

      filter expr(
               is_nil(^arg(:query)) or contains(title, ^arg(:query)) or
                 contains(artist.name, ^arg(:query))
             )

      prepare Plattensammlung.Records.Preparations.ScopeToOwner
      prepare Plattensammlung.Records.Preparations.AlbumFilters
      prepare build(sort: [title: :asc], load: [:artist])
    end

    read :by_barcode do
      description "Albums of which the actor has a copy with this barcode."
      argument :barcode, :string, allow_nil?: false, constraints: [max_length: 20]
      filter expr(exists(copies, barcode == ^arg(:barcode) and owner_id == ^actor(:id)))
    end

    action :lookup, {:array, Plattensammlung.Records.LookupResult} do
      description """
      Searches Discogs and MusicBrainz by barcode or by artist and title.
      A generic action: it runs custom code instead of reading or writing rows.
      """

      argument :query, :string, allow_nil?: false, constraints: [max_length: 200]

      run fn input, _context ->
        Plattensammlung.Lookup.search(input.arguments.query)
      end
    end

    action :find_matches, {:array, Plattensammlung.Records.LookupResult} do
      description """
      Candidates from Discogs/MusicBrainz to update an existing album with:
      by its stored ids, otherwise by artist and title, or by the given query.
      """

      argument :album_id, :uuid, allow_nil?: false
      argument :query, :string, constraints: [max_length: 200]

      run fn input, context ->
        opts = Ash.Context.to_opts(context)

        with {:ok, album} <-
               Plattensammlung.Records.get_album(
                 input.arguments.album_id,
                 [load: [:artist]] ++ opts
               ) do
          Plattensammlung.Lookup.for_album(album, input.arguments[:query])
        end
      end
    end

    update :upload_cover do
      description "Replaces the cover with an uploaded image (JPEG, PNG, WebP or GIF)."
      argument :image, :file, allow_nil?: false
      require_atomic? false
      change Plattensammlung.Records.Changes.StoreUploadedCover
    end

    update :remove_cover do
      require_atomic? false
      change set_attribute(:cover_url, nil)
      # Deletes the previous local file once the update is saved
      change Plattensammlung.Records.Changes.StoreCover
    end

    update :apply_match do
      description "Takes album data from a lookup result: fill empty fields or overwrite."
      argument :result, Plattensammlung.Records.LookupResult, allow_nil?: false

      argument :mode, :atom do
        default :fill
        constraints one_of: [:fill, :overwrite]
      end

      argument :copy_id, :uuid do
        description "Own copy of this album that gets the pressing details of a barcode result"
      end

      argument :new_copy, :boolean do
        description "Add the pressing as a new own copy instead"
        default false
      end

      require_atomic? false

      # Order matters: StoreCover downloads the cover that ApplyMatch set
      change Plattensammlung.Records.Changes.ApplyMatch
      # After ApplyMatch: the lookup result is an argument and may come from the API
      validate Plattensammlung.Records.Validations.CoverSource
      change Plattensammlung.Records.Changes.StoreCover
      change Plattensammlung.Records.Changes.FillStreamingLinks
    end

    update :find_streaming_links do
      description "Fills missing Spotify/Tidal ids from Wikidata (needs a Discogs or MusicBrainz link)."
      require_atomic? false
      change Plattensammlung.Records.Changes.FillStreamingLinks
    end

    action :statistics, :map do
      description "Key figures and breakdowns (genres, decades, conditions, artists)."
      argument :owner_id, :uuid, description: "Whose collection (default: the actor's)"
      run Plattensammlung.Records.Statistics
    end

    read :duplicates do
      description "Albums in the catalog with exactly this artist and title (case-insensitive)."
      argument :artist_name, :ci_string, allow_nil?: false, constraints: [max_length: 200]
      argument :title, :ci_string, allow_nil?: false, constraints: [max_length: 200]

      filter expr(title == ^arg(:title) and artist.name == ^arg(:artist_name))
    end

    read :collection do
      argument :owner_id, :uuid, description: "Whose collection (default: the actor's)"
      prepare {Plattensammlung.Records.Preparations.ScopeToOwner, status: :collection}
      prepare build(sort: [title: :asc], load: [:artist])
    end

    read :wishlist do
      argument :owner_id, :uuid, description: "Whose wishlist (default: the actor's)"
      prepare {Plattensammlung.Records.Preparations.ScopeToOwner, status: :wishlist}
      prepare build(sort: [title: :asc], load: [:artist])
    end
  end

  # Albums are shared (ADR 0016): everyone signed in reads them and may add an
  # own copy or wish. The shared data is changed by everyone who has the album
  # in collection or wishlist; it is deleted only once no one has it any more.
  policies do
    policy action_type([:read, :create, :action]) do
      # :strict raises Forbidden instead of silently returning no rows
      access_type :strict
      authorize_if actor_present()
    end

    policy action_type(:update) do
      forbid_unless actor_present()
      # Putting an album on the own wishlist needs no copy or wish yet
      authorize_if action([:mark_wanted, :unmark_wanted])

      authorize_if expr(
                     exists(copies, owner_id == ^actor(:id)) or
                       exists(wishes, owner_id == ^actor(:id))
                   )
    end

    policy action_type(:destroy) do
      forbid_unless actor_present()
      authorize_if expr(not exists(copies, true) and not exists(wishes, true))
    end
  end

  attributes do
    # Public, so the generic add actions return it in the API
    uuid_v7_primary_key :id, public?: true

    attribute :title, :ci_string do
      allow_nil? false
      constraints max_length: 200
      public? true
    end

    attribute :year, :integer do
      description "Year of the original release"
      constraints min: 1900, max: 2100
      public? true
    end

    attribute :cover_url, :string, public?: true

    attribute :genres, {:array, :string} do
      constraints max_length: 20, items: [max_length: 50]
      default []
      allow_nil? false
      public? true
    end

    attribute :discogs_master_id, :integer, constraints: [min: 1], public?: true
    attribute :musicbrainz_release_group_id, :uuid, public?: true

    attribute :spotify_album_id, :string do
      constraints max_length: 100
      description "Spotify album id (a pasted link is reduced to the id)"
      public? true
    end

    attribute :tidal_album_id, :string do
      constraints max_length: 100
      description "Tidal album id (a pasted link is reduced to the id)"
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :artist, Plattensammlung.Records.Artist do
      allow_nil? false
      public? true
    end

    has_many :copies, Plattensammlung.Records.Copy do
      description "Copies of all users"
      public? true
    end

    has_many :wishes, Plattensammlung.Records.Wish do
      description "Wishes of all users"
      public? true
    end
  end

  calculations do
    # The actor's view of a shared album, computed by the database on demand
    calculate :owned, :boolean, expr(exists(copies, owner_id == ^actor(:id))), public?: true
    calculate :wanted, :boolean, expr(exists(wishes, owner_id == ^actor(:id))), public?: true

    calculate :copy_count,
              :integer,
              expr(count(copies, query: [filter: expr(owner_id == ^actor(:id))])),
              public?: true

    calculate :spotify_url,
              :string,
              expr(
                if is_nil(spotify_album_id) do
                  nil
                else
                  "https://open.spotify.com/album/" <> spotify_album_id
                end
              ),
              public?: true

    calculate :tidal_url,
              :string,
              expr(
                if is_nil(tidal_album_id) do
                  nil
                else
                  "https://tidal.com/album/" <> tidal_album_id
                end
              ),
              public?: true

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
end
