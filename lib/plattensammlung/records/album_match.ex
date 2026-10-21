defmodule Plattensammlung.Records.AlbumMatch do
  @moduledoc """
  Which album fields a lookup result would change (see `Album.apply_match`).

  * `:fill` – only fields that are still empty. A cover that is still a remote
    URL (its download failed earlier) counts as empty, so it is retried.
  * `:overwrite` – every field the result has a value for.

  Artist and title are never changed: they are what the user entered.

  `copy_changes/3` does the same for the pressing details of a copy, which a
  barcode result carries (barcode, label, catalog number, …).
  """
  alias Plattensammlung.Covers

  @fields [
    :year,
    :genres,
    :cover_url,
    :discogs_master_id,
    :musicbrainz_release_group_id,
    :spotify_album_id
  ]

  @copy_fields [
    :barcode,
    :label,
    :catalog_number,
    :country,
    :pressing_year,
    :format,
    :discogs_release_id,
    :musicbrainz_release_id
  ]

  @labels %{
    barcode: "Barcode",
    label: "Label",
    catalog_number: "Katalognummer",
    country: "Land",
    pressing_year: "Jahr der Pressung",
    format: "Format",
    discogs_release_id: "Discogs-Pressung",
    musicbrainz_release_id: "MusicBrainz-Pressung",
    year: "Jahr",
    genres: "Genres",
    cover_url: "Cover",
    discogs_master_id: "Discogs-Verknüpfung",
    musicbrainz_release_group_id: "MusicBrainz-Verknüpfung",
    spotify_album_id: "Spotify-Verknüpfung"
  }

  @doc "Map of field => new value."
  def changes(album, result, mode) when mode in [:fill, :overwrite] do
    for field <- @fields,
        new = Map.get(result, field),
        present?(new),
        change?(mode, field, Map.get(album, field), new),
        into: %{},
        do: {field, new}
  end

  @doc "Pressing fields of a copy that the result would change."
  def copy_changes(copy, result, mode) when mode in [:fill, :overwrite] do
    for field <- @copy_fields,
        new = Map.get(result, field),
        present?(new),
        change?(mode, field, Map.get(copy, field), new),
        into: %{},
        do: {field, new}
  end

  @doc "Whether the result carries pressing details (only barcode lookups do)."
  def pressing?(result), do: present?(result.barcode)

  @doc "German labels of the changed fields, for the UI."
  def labels(changes), do: changes |> Map.keys() |> Enum.sort() |> Enum.map(&@labels[&1])

  defp change?(:fill, field, current, _new), do: missing?(field, current)

  # A different cover URL from the source always differs from our local copy;
  # only replace it when explicitly overwriting
  defp change?(:overwrite, _field, current, new), do: current != new

  defp missing?(:cover_url, url), do: is_nil(url) or Covers.remote?(url)
  defp missing?(_field, value), do: not present?(value)

  defp present?(nil), do: false
  defp present?([]), do: false
  defp present?(""), do: false
  defp present?(_value), do: true
end
