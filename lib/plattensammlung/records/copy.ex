defmodule Plattensammlung.Records.Copy do
  @moduledoc """
  A copy of an album that is actually owned. Every field except the album is
  optional; pressing details mirror a Discogs/MusicBrainz release (see ADR 0006).
  """
  use Ash.Resource,
    otp_app: :plattensammlung,
    domain: Plattensammlung.Records,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    extensions: [AshJsonApi.Resource]

  json_api do
    type "copy"
    includes [:album]

    default_fields [
      :album_id,
      :label,
      :catalog_number,
      :barcode,
      :country,
      :pressing_year,
      :format,
      :discogs_release_id,
      :musicbrainz_release_id,
      :media_condition,
      :sleeve_condition,
      :purchased_on,
      :notes,
      :discogs_url
    ]
  end

  postgres do
    table "copies"
    repo Plattensammlung.Repo

    custom_indexes do
      # Fast "do I own this pressing?" check when scanning
      index [:barcode]
    end

    references do
      # Deleting an album deletes its copies
      reference :album, on_delete: :delete
    end
  end

  # Purchase date and notes are private: others get `%Ash.ForbiddenField{}`,
  # the JSON:API leaves them out (ADR 0013)
  field_policies do
    field_policy [:purchased_on, :notes] do
      authorize_if expr(album.owner_id == ^actor(:id))
    end

    field_policy :* do
      authorize_if always()
    end
  end

  actions do
    @fields [
      :label,
      :catalog_number,
      :barcode,
      :country,
      :pressing_year,
      :format,
      :discogs_release_id,
      :musicbrainz_release_id,
      :media_condition,
      :sleeve_condition,
      :purchased_on,
      :notes
    ]

    defaults [:read, :destroy]

    create :create do
      primary? true
      accept @fields ++ [:album_id]

      change Plattensammlung.Records.Changes.NormalizeBarcode
      validate match(:barcode, ~r/^\d{8,14}$/), message: "must be 8 to 14 digits (EAN/UPC)"
      change Plattensammlung.Records.Changes.RemoveFromWishlist
    end

    update :update do
      primary? true
      accept @fields
      require_atomic? false

      change Plattensammlung.Records.Changes.NormalizeBarcode
      validate match(:barcode, ~r/^\d{8,14}$/), message: "must be 8 to 14 digits (EAN/UPC)"
    end
  end

  # Copies follow their album: readable for every signed-in user, changeable
  # only by the album's owner (ADR 0013)
  policies do
    policy action_type(:read) do
      access_type :strict
      authorize_if actor_present()
    end

    policy action_type(:create) do
      authorize_if Plattensammlung.Records.Checks.AlbumOwnedByActor
    end

    policy action_type([:update, :destroy]) do
      authorize_if expr(album.owner_id == ^actor(:id))
    end
  end

  attributes do
    uuid_v7_primary_key :id

    attribute :label, :string, constraints: [max_length: 100], public?: true
    attribute :catalog_number, :string, constraints: [max_length: 100], public?: true

    attribute :barcode, :string do
      description "EAN/UPC (GTIN) printed on the sleeve"
      public? true
    end

    attribute :country, :string, constraints: [max_length: 100], public?: true
    attribute :pressing_year, :integer, constraints: [min: 1900, max: 2100], public?: true

    attribute :format, {:array, :string} do
      description "Format tags, e.g. [\"Vinyl\", \"LP\", \"Album\"] or [\"7\\\"\", \"Single\"]"
      constraints max_length: 20, items: [max_length: 50]
      default []
      allow_nil? false
      public? true
    end

    attribute :discogs_release_id, :integer, constraints: [min: 1], public?: true
    attribute :musicbrainz_release_id, :uuid, public?: true
    attribute :media_condition, Plattensammlung.Records.Condition, public?: true
    attribute :sleeve_condition, Plattensammlung.Records.Condition, public?: true
    attribute :purchased_on, :date, public?: true

    attribute :notes, :string, constraints: [max_length: 2000], public?: true

    timestamps()
  end

  relationships do
    belongs_to :album, Plattensammlung.Records.Album do
      allow_nil? false
      public? true
    end
  end

  calculations do
    calculate :discogs_url,
              :string,
              expr(
                if is_nil(discogs_release_id) do
                  nil
                else
                  "https://www.discogs.com/release/" <> type(discogs_release_id, :string)
                end
              ),
              public?: true
  end
end
