defmodule Plattensammlung.Records.Export do
  @moduledoc """
  Exports the collection (see ADR 0010).

  * `csv/1` – every field, one row per copy plus one row per wishlist album.
    Meant as a backup and for spreadsheets; column names match the API fields.
  * `json_ld/2` – the owned albums as a schema.org `ItemList` of `MusicAlbum`s
    with their `MusicRelease`s (pressings). Private details (price, purchase
    date, notes) are left out, so it can be shared.

  Data is read through the Records domain with the given options (actor).
  """
  alias Plattensammlung.Records
  alias Plattensammlung.Records.Condition

  NimbleCSV.define(__MODULE__.CSV, separator: ",", escape: "\"")

  @csv_columns ~w(status artist title year genres format label catalog_number barcode country
                  pressing_year media_condition sleeve_condition purchased_on
                  notes discogs_master_id discogs_release_id
                  musicbrainz_release_group_id musicbrainz_release_id)

  @doc "CSV text with a header row."
  def csv(opts) do
    rows =
      opts
      |> all_albums()
      |> Enum.flat_map(fn album ->
        case album.copies do
          [] -> [csv_row(album, nil)]
          copies -> Enum.map(copies, &csv_row(album, &1))
        end
      end)

    [@csv_columns | rows]
    |> __MODULE__.CSV.dump_to_iodata()
    |> IO.iodata_to_binary()
  end

  @doc "schema.org JSON-LD map; `base_url` turns local cover paths into absolute URLs."
  def json_ld(opts, base_url) do
    albums = opts |> all_albums() |> Enum.filter(&(&1.copies != []))

    %{
      "@context" => "https://schema.org",
      "@type" => "ItemList",
      "name" => "Plattensammlung",
      "numberOfItems" => length(albums),
      "dateModified" => Date.utc_today() |> Date.to_iso8601(),
      "itemListElement" =>
        albums
        |> Enum.with_index(1)
        |> Enum.map(fn {album, position} ->
          %{"@type" => "ListItem", "position" => position, "item" => music_album(album, base_url)}
        end)
    }
  end

  defp all_albums(opts) do
    Records.search_albums!(nil, nil, Keyword.put(opts, :load, [:artist, :copies]))
    |> Enum.sort_by(
      &{String.downcase(to_string(&1.artist.name)), String.downcase(to_string(&1.title))}
    )
  end

  defp csv_row(album, copy) do
    copy_value = fn field -> copy && Map.get(copy, field) end

    [
      if(copy, do: "collection", else: "wishlist"),
      album.artist.name,
      album.title,
      album.year,
      Enum.join(album.genres, "; "),
      copy_value.(:format),
      copy_value.(:label),
      copy_value.(:catalog_number),
      copy_value.(:barcode),
      copy_value.(:country),
      copy_value.(:pressing_year),
      condition(copy_value.(:media_condition)),
      condition(copy_value.(:sleeve_condition)),
      copy_value.(:purchased_on),
      copy_value.(:notes),
      album.discogs_master_id,
      copy_value.(:discogs_release_id),
      album.musicbrainz_release_group_id,
      copy_value.(:musicbrainz_release_id)
    ]
    |> Enum.map(&cell/1)
  end

  defp cell(nil), do: ""
  defp cell(%Date{} = date), do: Date.to_iso8601(date)
  defp cell(%Decimal{} = decimal), do: Decimal.to_string(decimal, :normal)
  defp cell(value), do: to_string(value)

  # Short Goldmine grade, e.g. "VG+"
  defp condition(nil), do: nil

  defp condition(value) do
    case Regex.run(~r/\(([^)]+)\)/, Condition.description(value)) do
      [_, short] -> short
      _ -> to_string(value)
    end
  end

  defp music_album(album, base_url) do
    %{
      "@type" => "MusicAlbum",
      "name" => to_string(album.title),
      "byArtist" => %{"@type" => "MusicGroup", "name" => to_string(album.artist.name)},
      "datePublished" => album.year && to_string(album.year),
      "genre" => album.genres,
      "image" => image(album.cover_url, base_url),
      "sameAs" =>
        compact([
          album.discogs_master_id && "https://www.discogs.com/master/#{album.discogs_master_id}",
          album.musicbrainz_release_group_id &&
            "https://musicbrainz.org/release-group/#{album.musicbrainz_release_group_id}"
        ]),
      "albumRelease" => Enum.map(album.copies, &music_release(&1, album))
    }
    |> compact()
  end

  defp music_release(copy, album) do
    %{
      "@type" => "MusicRelease",
      "name" => to_string(album.title),
      "musicReleaseFormat" => "https://schema.org/VinylFormat",
      "catalogNumber" => copy.catalog_number,
      "recordLabel" => copy.label && %{"@type" => "Organization", "name" => copy.label},
      "datePublished" => copy.pressing_year && to_string(copy.pressing_year),
      "description" => copy.format,
      "identifier" =>
        copy.barcode &&
          %{"@type" => "PropertyValue", "propertyID" => "GTIN", "value" => copy.barcode},
      "sameAs" =>
        compact([
          copy.discogs_release_id && "https://www.discogs.com/release/#{copy.discogs_release_id}",
          copy.musicbrainz_release_id &&
            "https://musicbrainz.org/release/#{copy.musicbrainz_release_id}"
        ])
    }
    |> compact()
  end

  defp image(nil, _base_url), do: nil
  defp image("/" <> _ = path, base_url), do: base_url <> path
  defp image(url, _base_url), do: url

  # Leave out empty values instead of writing nulls
  defp compact(list) when is_list(list), do: Enum.reject(list, &(&1 in [nil, false]))

  defp compact(map) when is_map(map) do
    map |> Enum.reject(fn {_key, value} -> value in [nil, false, [], ""] end) |> Map.new()
  end
end
