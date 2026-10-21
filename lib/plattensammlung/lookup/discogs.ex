defmodule Plattensammlung.Lookup.Discogs do
  @moduledoc """
  Client for the Discogs database API (https://www.discogs.com/developers).

  Needs a personal access token (`DISCOGS_TOKEN`). Text searches return
  *masters* (albums); a barcode resolves to one release (pressing) whose master
  supplies the album data, so nobody has to pick between pressings.
  """
  alias Plattensammlung.Lookup.HTTP

  @base_url "https://api.discogs.com"

  def configured?, do: token() not in [nil, ""]

  @doc "Albums (masters) matching a free text query."
  def search(query) do
    with {:ok, body} <- get("/database/search", q: query, type: "master", per_page: 10) do
      {:ok, Enum.map(results(body), &from_master_search/1)}
    end
  end

  @doc "The first pressing with this barcode, enriched with its album (master) data."
  def by_barcode(barcode) do
    with {:ok, body} <- get("/database/search", barcode: barcode, type: "release", per_page: 1) do
      case results(body) do
        [] -> {:ok, []}
        [release | _] -> {:ok, [release |> from_release_search(barcode) |> merge_master()]}
      end
    end
  end

  @doc "The album (master) with this Discogs id."
  def by_master_id(id) do
    case get("/masters/#{id}", []) do
      {:ok, %{} = master} -> {:ok, [from_master(master)]}
      {:ok, nil} -> {:ok, []}
      error -> error
    end
  end

  defp get(path, params) do
    [base_url: @base_url, headers: [authorization: "Discogs token=#{token()}"]]
    |> HTTP.new()
    |> HTTP.get_json(path, params)
  end

  defp token, do: Application.get_env(:plattensammlung, :discogs_token)

  defp results(%{"results" => results}) when is_list(results), do: results
  defp results(_body), do: []

  defp from_master_search(result) do
    {artist, title} = split_title(result["title"])

    %{
      source: :discogs,
      artist_name: artist,
      title: title,
      year: parse_year(result["year"]),
      genres: result["genre"] || [],
      cover_url: image(result["cover_image"]),
      thumb_url: image(result["thumb"]),
      discogs_master_id: result["id"]
    }
  end

  defp from_release_search(result, barcode) do
    {artist, title} = split_title(result["title"])

    %{
      source: :discogs,
      artist_name: artist,
      title: title,
      year: parse_year(result["year"]),
      genres: result["genre"] || [],
      cover_url: image(result["cover_image"]),
      thumb_url: image(result["thumb"]),
      discogs_master_id: positive(result["master_id"]),
      barcode: barcode,
      label: List.first(result["label"] || []),
      catalog_number: result["catno"],
      country: result["country"],
      pressing_year: parse_year(result["year"]),
      format: format(result["format"]),
      discogs_release_id: result["id"]
    }
  end

  defp from_master(master) do
    images = Map.get(master, "images", [])

    %{
      source: :discogs,
      artist_name: master_artist(master),
      title: master["title"],
      year: parse_year(master["year"]),
      genres: master["genres"] || [],
      cover_url: primary_image(images),
      thumb_url: images |> List.first(%{}) |> Map.get("uri150") |> image(),
      discogs_master_id: master["id"]
    }
  end

  # The master knows the original release year and the canonical album data
  defp merge_master(%{discogs_master_id: nil} = result), do: result

  defp merge_master(%{discogs_master_id: id} = result) do
    case get("/masters/#{id}", []) do
      {:ok, %{} = master} ->
        cover = master |> Map.get("images", []) |> primary_image()

        %{
          result
          | artist_name: master_artist(master) || result.artist_name,
            title: master["title"] || result.title,
            year: parse_year(master["year"]) || result.year,
            genres: master["genres"] || result.genres,
            cover_url: cover || result.cover_url
        }

      _ ->
        result
    end
  end

  # Discogs titles look like "The Beatles - Abbey Road"
  defp split_title(nil), do: {nil, nil}

  defp split_title(full) do
    case String.split(full, " - ", parts: 2) do
      [artist, title] -> {clean_artist(artist), title}
      [title] -> {nil, title}
    end
  end

  defp master_artist(%{"artists" => [%{"name" => name} | _]}), do: clean_artist(name)
  defp master_artist(_master), do: nil

  # Discogs disambiguates equal names with a number: "Nirvana (2)"
  defp clean_artist(name), do: name |> String.replace(~r/\s\(\d+\)$/, "") |> String.trim()

  defp primary_image(images) do
    image = Enum.find(images, &(&1["type"] == "primary")) || List.first(images)
    image && image(image["uri"])
  end

  # Discogs returns a spacer image when there is no cover
  defp image(nil), do: nil
  defp image(""), do: nil
  defp image(url), do: if(String.ends_with?(url, "spacer.gif"), do: nil, else: url)

  defp format(nil), do: nil
  defp format(formats), do: formats |> Enum.take(3) |> Enum.join(", ")

  defp positive(id) when is_integer(id) and id > 0, do: id
  defp positive(_id), do: nil

  defp parse_year(year) when is_integer(year) and year > 0, do: year

  defp parse_year(year) when is_binary(year) do
    case Integer.parse(year) do
      {year, _} when year > 0 -> year
      _ -> nil
    end
  end

  defp parse_year(_year), do: nil
end
