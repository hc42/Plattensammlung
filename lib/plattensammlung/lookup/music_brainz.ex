defmodule Plattensammlung.Lookup.MusicBrainz do
  @moduledoc """
  Client for the MusicBrainz web service (https://musicbrainz.org/doc/MusicBrainz_API)
  with covers from the Cover Art Archive. No account needed; MusicBrainz allows
  about one request per second.

  Text searches return *release groups* (albums); a barcode resolves to one
  release (pressing) and its release group.
  """
  alias Plattensammlung.Lookup.HTTP

  @base_url "https://musicbrainz.org/ws/2"

  def configured?, do: true

  @doc "Albums (release groups) matching a free text query."
  def search(query) do
    # dismax searches title and artist together without Lucene syntax
    with {:ok, body} <- get("/release-group", query: query, dismax: true, limit: 10) do
      groups = (body || %{}) |> Map.get("release-groups", [])
      {:ok, Enum.map(groups, &from_release_group/1)}
    end
  end

  @doc "The best matching release for this barcode, with its album data."
  def by_barcode(barcode) do
    with {:ok, body} <- get("/release", query: "barcode:#{barcode}", limit: 1) do
      case (body || %{}) |> Map.get("releases", []) do
        [] -> {:ok, []}
        [release | _] -> {:ok, [from_release(release, barcode)]}
      end
    end
  end

  @doc "The album (release group) with this MusicBrainz id, including its top genres."
  def by_release_group_id(id) do
    case get("/release-group/#{id}", inc: "artist-credits genres") do
      {:ok, %{} = group} ->
        {:ok, [group |> from_release_group() |> Map.put(:genres, genres(group))]}

      {:ok, nil} ->
        {:ok, []}

      error ->
        error
    end
  end

  # Community-voted genres, most votes first: "art rock" -> "Art Rock"
  defp genres(group) do
    group
    |> Map.get("genres", [])
    |> Enum.sort_by(&(-(&1["count"] || 0)))
    |> Enum.take(3)
    |> Enum.map(fn %{"name" => name} ->
      name |> String.split(" ") |> Enum.map_join(" ", &String.capitalize/1)
    end)
  end

  defp get(path, params) do
    [base_url: @base_url]
    |> HTTP.new()
    |> HTTP.get_json(path, Keyword.put(params, :fmt, "json"))
  end

  defp from_release_group(group) do
    %{
      source: :musicbrainz,
      artist_name: artist_credit(group["artist-credit"]),
      title: group["title"],
      year: year(group["first-release-date"]),
      genres: [],
      cover_url: cover(group["id"], 500),
      thumb_url: cover(group["id"], 250),
      musicbrainz_release_group_id: group["id"]
    }
  end

  defp from_release(release, barcode) do
    group = release["release-group"] || %{}
    label_info = List.first(release["label-info"] || []) || %{}

    %{
      source: :musicbrainz,
      artist_name: artist_credit(release["artist-credit"]),
      title: group["title"] || release["title"],
      # A search result has no first release date; the pressing year is the best we have
      year: year(release["date"]),
      genres: [],
      cover_url: cover(group["id"], 500),
      thumb_url: cover(group["id"], 250),
      musicbrainz_release_group_id: group["id"],
      barcode: barcode,
      label: get_in(label_info, ["label", "name"]),
      catalog_number: label_info["catalog-number"],
      country: release["country"],
      pressing_year: year(release["date"]),
      format: format(release["media"]),
      musicbrainz_release_id: release["id"]
    }
  end

  # "artist-credit" is a list of names joined by phrases like " & "
  defp artist_credit(nil), do: nil

  defp artist_credit(credits) do
    Enum.map_join(credits, fn credit -> credit["name"] <> (credit["joinphrase"] || "") end)
  end

  defp cover(nil, _size), do: nil
  defp cover(id, size), do: "https://coverartarchive.org/release-group/#{id}/front-#{size}"

  defp format(nil), do: nil

  defp format(media) do
    case media |> Enum.map(& &1["format"]) |> Enum.reject(&is_nil/1) do
      [] -> nil
      [single] -> single
      [first | _] = all -> "#{length(all)}× #{first}"
    end
  end

  defp year("" <> date) do
    case Integer.parse(date) do
      {year, _} when year > 0 -> year
      _ -> nil
    end
  end

  defp year(_date), do: nil
end
