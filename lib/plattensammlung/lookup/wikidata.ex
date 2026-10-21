defmodule Plattensammlung.Lookup.Wikidata do
  @moduledoc """
  Spotify and Tidal album ids from Wikidata (properties P2205 and P4577),
  found via the album's MusicBrainz release group id (P436) or Discogs master
  id (P1954). Open data, no account needed (see ADR 0012).
  """
  alias Plattensammlung.Lookup.HTTP

  @endpoint "https://query.wikidata.org/sparql"

  @spec streaming_ids(String.t() | nil, integer() | nil) ::
          {:ok, %{spotify: String.t() | nil, tidal: String.t() | nil}} | {:error, term()}
  def streaming_ids(nil, nil), do: {:ok, %{spotify: nil, tidal: nil}}

  def streaming_ids(musicbrainz_id, discogs_id) do
    with {:ok, body} <- run(query(musicbrainz_id, discogs_id)), do: {:ok, first_ids(body)}
  end

  @doc "MusicBrainz release group and Discogs master id of the album with this Spotify id."
  @spec album_for_spotify(String.t()) ::
          {:ok, %{musicbrainz: String.t() | nil, discogs: integer() | nil}} | {:error, term()}
  def album_for_spotify(spotify_id) do
    sparql = """
    SELECT ?musicbrainz ?discogs WHERE {
      ?item wdt:P2205 "#{escape(spotify_id)}" .
      OPTIONAL { ?item wdt:P436 ?musicbrainz }
      OPTIONAL { ?item wdt:P1954 ?discogs }
    } LIMIT 5
    """

    with {:ok, %{"results" => %{"bindings" => rows}}} <- run(sparql) do
      discogs = Enum.find_value(rows, &get_in(&1, ["discogs", "value"]))

      {:ok,
       %{
         musicbrainz: Enum.find_value(rows, &get_in(&1, ["musicbrainz", "value"])),
         discogs: discogs && String.to_integer(discogs)
       }}
    end
  end

  defp run(sparql) do
    req =
      HTTP.new(
        receive_timeout: 8_000,
        retry: false,
        headers: [accept: "application/sparql-results+json"]
      )

    case Req.get(req, url: @endpoint, params: [query: sparql]) do
      {:ok, %{status: 200, body: %{} = body}} -> {:ok, body}
      {:ok, %{status: status}} -> {:error, {:http_status, status}}
      {:error, exception} -> {:error, exception}
    end
  end

  defp query(musicbrainz_id, discogs_id) do
    matches =
      [
        musicbrainz_id && ~s({ ?item wdt:P436 "#{escape(musicbrainz_id)}" }),
        discogs_id && ~s({ ?item wdt:P1954 "#{escape(to_string(discogs_id))}" })
      ]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" UNION ")

    """
    SELECT ?spotify ?tidal WHERE {
      #{matches}
      OPTIONAL { ?item wdt:P2205 ?spotify }
      OPTIONAL { ?item wdt:P4577 ?tidal }
    } LIMIT 20
    """
  end

  # Ids are UUIDs and integers; strip anything that could break the query
  defp escape(value), do: String.replace(value, ~r/[^0-9A-Za-z-]/, "")

  # Several rows when an album has more than one Tidal id; take the first of each
  defp first_ids(%{"results" => %{"bindings" => rows}}) do
    %{spotify: first(rows, "spotify"), tidal: first(rows, "tidal")}
  end

  defp first_ids(_body), do: %{spotify: nil, tidal: nil}

  defp first(rows, key), do: Enum.find_value(rows, &get_in(&1, [key, "value"]))
end
