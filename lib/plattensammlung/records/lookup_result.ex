defmodule Plattensammlung.Records.LookupResult do
  @moduledoc """
  An album found in an external catalog, optionally with the pressing that
  matched a barcode. Not stored in the database: an *embedded* resource is a
  typed struct that Ash can validate and serialize (e.g. for the JSON API).
  """
  use Ash.Resource, data_layer: :embedded

  attributes do
    attribute :source, :atom do
      constraints one_of: [:discogs, :musicbrainz]
      public? true
    end

    # Album
    attribute :artist_name, :string, public?: true
    attribute :title, :string, public?: true
    attribute :year, :integer, public?: true
    attribute :genres, {:array, :string}, default: [], public?: true
    attribute :cover_url, :string, public?: true
    attribute :thumb_url, :string, public?: true
    attribute :discogs_master_id, :integer, public?: true
    attribute :musicbrainz_release_group_id, :string, public?: true

    # Pressing (only for barcode lookups)
    attribute :barcode, :string, public?: true
    attribute :label, :string, public?: true
    attribute :catalog_number, :string, public?: true
    attribute :country, :string, public?: true
    attribute :pressing_year, :integer, public?: true
    attribute :format, :string, public?: true
    attribute :discogs_release_id, :integer, public?: true
    attribute :musicbrainz_release_id, :string, public?: true
  end
end
