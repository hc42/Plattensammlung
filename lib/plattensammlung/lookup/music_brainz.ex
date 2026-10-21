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

  @doc """
  The release group (album) that a streaming or shop URL belongs to, e.g. a
  Spotify album link that MusicBrainz editors attached to one of its releases.
  """
  def release_group_for_url(url) do
    with {:ok, body} <- get("/url", resource: url, inc: "release-rels release-group-rels") do
      relations = (body || %{}) |> Map.get("relations", [])

      case Enum.find_value(relations, &get_in(&1, ["release_group", "id"])) do
        nil ->
          release_group_of_release(Enum.find_value(relations, &get_in(&1, ["release", "id"])))

        group ->
          {:ok, group}
      end
    end
  end

  defp release_group_of_release(nil), do: {:ok, nil}

  defp release_group_of_release(release_id) do
    with {:ok, body} <- get("/release/#{release_id}", inc: "release-groups") do
      {:ok, get_in(body || %{}, ["release-group", "id"])}
    end
  end

  @doc "The release group (album) linked to a Discogs master, or nil."
  def release_group_for_discogs_master(master_id) do
    params = [resource: "https://www.discogs.com/master/#{master_id}", inc: "release-group-rels"]

    with {:ok, body} <- get("/url", params) do
      {:ok,
       (body || %{})
       |> Map.get("relations", [])
       |> Enum.find_value(&get_in(&1, ["release_group", "id"]))}
    end
  end

  @doc """
  The release group (album) with exactly this title by this artist, or nil.
  Only exact matches (ignoring case) count, studio albums before compilations,
  so an album never gets linked to a merely similar one.
  """
  def release_group_for_name(artist, title) do
    query =
      "releasegroup:#{phrase(title)} AND artist:#{phrase(artist)} AND primarytype:album"

    with {:ok, body} <- get("/release-group", query: query, limit: 10) do
      {:ok,
       (body || %{})
       |> Map.get("release-groups", [])
       |> Enum.filter(&(same?(&1["title"], title) and credited?(&1, artist)))
       |> Enum.sort_by(&length(&1["secondary-types"] || []))
       |> Enum.find_value(& &1["id"])}
    end
  end

  # Lucene phrase: quotes and backslashes escaped
  defp phrase(text), do: ~s(") <> String.replace(to_string(text), ~r/["\\]/, "\\\\\\0") <> ~s(")

  defp same?(a, b) when is_binary(a),
    do: String.downcase(String.trim(a)) == String.downcase(String.trim(to_string(b)))

  defp same?(_a, _b), do: false

  defp credited?(group, artist),
    do: Enum.any?(group["artist-credit"] || [], &same?(&1["name"], artist))

  @doc """
  Spotify and Tidal album ids linked to any release (pressing, digital edition)
  of the release group; the newest release with a link wins.
  """
  def streaming_links(release_group_id) do
    params = ["release-group": release_group_id, inc: "url-rels", limit: 100]

    with {:ok, body} <- get("/release", params) do
      urls =
        (body || %{})
        |> Map.get("releases", [])
        |> Enum.sort_by(&(&1["date"] || ""), :desc)
        |> Enum.flat_map(fn release ->
          for %{"url" => %{"resource" => url}} <- release["relations"] || [], do: url
        end)

      {:ok,
       %{
         spotify: first_id(urls, &Plattensammlung.Records.Streaming.spotify_id/1),
         tidal: first_id(urls, &Plattensammlung.Records.Streaming.tidal_id/1)
       }}
    end
  end

  defp first_id(urls, parse) do
    Enum.find_value(urls, fn url ->
      case parse.(url) do
        {:ok, id} -> id
        :error -> nil
      end
    end)
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

  defp format(nil), do: []

  # One tag per kind of medium, with the count for sets: ["2× 12\" Vinyl"]
  defp format(media) do
    media
    |> Enum.map(& &1["format"])
    |> Enum.reject(&is_nil/1)
    |> Enum.frequencies()
    |> Enum.map(fn
      {format, 1} -> format
      {format, count} -> "#{count}× #{format}"
    end)
  end

  defp year("" <> date) do
    case Integer.parse(date) do
      {year, _} when year > 0 -> year
      _ -> nil
    end
  end

  defp year(_date), do: nil
end
