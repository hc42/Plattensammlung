defmodule Plattensammlung.Lookup.StreamingLinks do
  @moduledoc """
  Finds Spotify and Tidal album ids for an album (see ADR 0012), step by step,
  stopping as soon as both are known:

  1. Without a MusicBrainz id, MusicBrainz maps the Discogs master to its
     release group (also returned, so the album gets linked).
  2. Wikidata: album-level Spotify (P2205) and Tidal (P4577) ids.
  3. MusicBrainz: streaming links of the album's individual releases, which
     editors add more often than Wikidata ids.

  Failing services are skipped; the result then has fewer ids.
  """
  alias Plattensammlung.Lookup.{MusicBrainz, Wikidata}

  require Logger

  @type ids :: %{
          spotify: String.t() | nil,
          tidal: String.t() | nil,
          musicbrainz: String.t() | nil
        }

  @spec find(%{optional(atom()) => term()}) :: ids()
  def find(album) do
    musicbrainz = album[:musicbrainz] || release_group_for(album[:discogs])
    ids = %{spotify: album[:spotify], tidal: album[:tidal], musicbrainz: musicbrainz}

    ids
    |> fill(fn -> Wikidata.streaming_ids(musicbrainz, album[:discogs]) end)
    |> fill(fn -> musicbrainz && MusicBrainz.streaming_links(musicbrainz) end)
  end

  defp release_group_for(nil), do: nil

  defp release_group_for(discogs) do
    case MusicBrainz.release_group_for_discogs_master(discogs) do
      {:ok, id} -> id
      {:error, reason} -> log(reason)
    end
  end

  defp fill(%{spotify: spotify, tidal: tidal} = ids, _fetch)
       when is_binary(spotify) and is_binary(tidal),
       do: ids

  defp fill(ids, fetch) do
    case fetch.() do
      {:ok, found} ->
        %{ids | spotify: ids.spotify || found.spotify, tidal: ids.tidal || found.tidal}

      nil ->
        ids

      {:error, reason} ->
        log(reason)
        ids
    end
  end

  defp log(reason) do
    Logger.warning("Streaming link lookup failed: #{inspect(reason)}")
    nil
  end
end
