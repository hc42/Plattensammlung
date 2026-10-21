defmodule Plattensammlung.Lookup.Spotify do
  @moduledoc """
  Finds the album behind a Spotify album link without a Spotify account
  (see ADR 0012):

  1. Wikidata maps the Spotify id to MusicBrainz/Discogs ids.
  2. MusicBrainz knows the link if an editor attached it to a release.
  3. Last resort (in `Plattensammlung.Lookup`): Spotify's public oEmbed gives
     the title only, which is then searched.
  """
  alias Plattensammlung.Lookup.{Discogs, HTTP, MusicBrainz, Wikidata}

  @doc "Lookup results (plain maps) for a Spotify album id, via Wikidata or MusicBrainz."
  def by_album_id(spotify_id) do
    linked =
      case Wikidata.album_for_spotify(spotify_id) do
        {:ok, %{musicbrainz: nil, discogs: nil}} -> via_musicbrainz(spotify_id)
        {:ok, ids} -> linked_albums(ids)
        {:error, _reason} -> via_musicbrainz(spotify_id)
      end

    {:ok, Enum.map(linked, &Map.put(&1, :spotify_album_id, spotify_id))}
  end

  defp via_musicbrainz(spotify_id) do
    case MusicBrainz.release_group_for_url("https://open.spotify.com/album/#{spotify_id}") do
      {:ok, group} when is_binary(group) -> linked_albums(%{musicbrainz: group, discogs: nil})
      _none -> []
    end
  end

  @doc "Album title from Spotify's oEmbed endpoint, e.g. \"Abbey Road (Remastered 2009)\"."
  def title(spotify_id) do
    req = HTTP.new(receive_timeout: 8_000, retry: false)
    url = "https://open.spotify.com/album/#{spotify_id}"

    case Req.get(req, url: "https://open.spotify.com/oembed", params: [url: url]) do
      {:ok, %{status: 200, body: %{"title" => title}}} -> {:ok, title}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  defp linked_albums(%{musicbrainz: musicbrainz, discogs: discogs}) do
    [
      discogs && Discogs.configured?() && fn -> Discogs.by_master_id(discogs) end,
      musicbrainz && fn -> MusicBrainz.by_release_group_id(musicbrainz) end
    ]
    |> Enum.filter(&is_function/1)
    |> Enum.flat_map(fn fetch ->
      case fetch.() do
        {:ok, results} -> results
        _error -> []
      end
    end)
  end
end
