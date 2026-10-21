defmodule Plattensammlung.Records.Streaming do
  @moduledoc """
  Spotify and Tidal album links (see ADR 0012). Albums store only the ids;
  users may paste a full link, which is reduced to the id here.
  """

  @doc "Spotify album id from an id, `spotify:album:…` or an open.spotify.com link."
  def spotify_id(value) do
    value = String.trim(value)

    cond do
      Regex.match?(~r/^[0-9A-Za-z]{22}$/, value) ->
        {:ok, value}

      match = Regex.run(~r/^spotify:album:([0-9A-Za-z]{22})$/, value) ->
        {:ok, Enum.at(match, 1)}

      match =
          Regex.run(
            ~r"^https?://open\.spotify\.com/(?:intl-[a-z-]+/)?album/([0-9A-Za-z]{22})",
            value
          ) ->
        {:ok, Enum.at(match, 1)}

      true ->
        :error
    end
  end

  @doc "Tidal album id from an id or a tidal.com / listen.tidal.com link."
  def tidal_id(value) do
    value = String.trim(value)

    cond do
      Regex.match?(~r/^\d+$/, value) ->
        {:ok, value}

      match = Regex.run(~r"^https?://(?:listen\.)?tidal\.com/(?:browse/)?album/(\d+)", value) ->
        {:ok, Enum.at(match, 1)}

      true ->
        :error
    end
  end

  def spotify_url(nil), do: nil
  def spotify_url(id), do: "https://open.spotify.com/album/#{id}"

  def tidal_url(nil), do: nil
  def tidal_url(id), do: "https://tidal.com/album/#{id}"
end
