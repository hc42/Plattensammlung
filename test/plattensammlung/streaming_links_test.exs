defmodule Plattensammlung.StreamingLinksTest do
  use Plattensammlung.DataCase, async: true

  @moduletag :capture_log

  alias Plattensammlung.{LookupStub, Records}
  alias Plattensammlung.Records.Streaming

  setup do
    %{user: user_fixture()}
  end

  describe "link parsing" do
    test "Spotify links, URIs and ids become the id" do
      id = "0ETFjACtuP2ADo6LFhL6HN"

      for input <- [
            id,
            "spotify:album:#{id}",
            "https://open.spotify.com/album/#{id}?si=abc",
            "https://open.spotify.com/intl-de/album/#{id}"
          ] do
        assert Streaming.spotify_id(input) == {:ok, id}
      end

      assert Streaming.spotify_id("https://open.spotify.com/track/#{id}") == :error
    end

    test "Tidal links and ids become the id" do
      for input <- [
            "55130630",
            "https://tidal.com/album/55130630",
            "https://listen.tidal.com/album/55130630/u"
          ] do
        assert Streaming.tidal_id(input) == {:ok, "55130630"}
      end

      assert Streaming.tidal_id("https://tidal.com/track/1") == :error
    end
  end

  describe "auto-fill" do
    test "an album known to Wikidata gets both links on import", %{user: user} do
      album =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{discogs_master_id: 24047},
          actor: user
        )

      assert album.spotify_album_id == "0ETFjACtuP2ADo6LFhL6HN"
      # Several Tidal ids on Wikidata: the first one wins
      assert album.tidal_album_id == "55130630"
    end

    test "otherwise MusicBrainz releases provide the links, found via the Discogs id", %{
      user: user
    } do
      album =
        Records.add_to_collection!(
          "The Oscar Peterson Trio",
          "Night Train",
          %{discogs_master_id: LookupStub.night_train_discogs_master()},
          actor: user
        )

      # The newest release with links wins; the MusicBrainz link is stored too
      assert album.spotify_album_id == "4gPYH4cFOgaukEpzcAr7vw"
      assert album.tidal_album_id == "129183356"
      assert album.musicbrainz_release_group_id == "9ce4b9ee-9ad4-3deb-95a4-4cb4e68c145e"
    end

    test "a Discogs master unknown to MusicBrainz falls back to artist and title", %{
      user: user
    } do
      # Discogs has side masters (e.g. reissues with all sidemen credited)
      album =
        Records.add_to_collection!("the beatles", "ABBEY ROAD", %{discogs_master_id: 1},
          actor: user
        )

      assert album.musicbrainz_release_group_id == "9162580e-5df4-32de-80cc-f45a8d8a9b1d"
      assert album.spotify_album_id == "0ETFjACtuP2ADo6LFhL6HN"

      # Only the exact title counts, not "Abbey Road Revisited"
      album =
        Records.add_to_collection!("The Beatles", "Abbey", %{discogs_master_id: 2}, actor: user)

      assert album.musicbrainz_release_group_id == nil
      assert album.spotify_album_id == nil
    end

    test "the fallback also works for an existing album", %{user: user} do
      album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)

      # Artist known only through artist_id here
      album = Records.update_album!(album, %{discogs_master_id: 1}, actor: user)

      assert album.spotify_album_id == "0ETFjACtuP2ADo6LFhL6HN"
    end

    test "existing albums are filled on request", %{user: user} do
      album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
      assert album.spotify_album_id == nil

      album =
        album
        |> Records.update_album!(%{discogs_master_id: 24047}, actor: user)

      assert album.spotify_album_id == "0ETFjACtuP2ADo6LFhL6HN"
    end

    test "manual links are kept and pasted links reduced to the id", %{user: user} do
      album =
        Records.add_to_collection!(
          "The Beatles",
          "Abbey Road",
          %{
            discogs_master_id: 24047,
            spotify_album_id: "https://open.spotify.com/album/1111111111111111111111"
          },
          actor: user
        )

      assert album.spotify_album_id == "1111111111111111111111"
      assert album.tidal_album_id == "55130630"
    end

    test "an invalid link is rejected", %{user: user} do
      assert {:error, error} =
               Records.add_to_collection(
                 "Can",
                 "Tago Mago",
                 %{tidal_album_id: "https://example.com/x"},
                 actor: user
               )

      assert Exception.message(error) =~ "is not a Tidal album link"
    end

    test "unavailable services leave the fields empty", %{user: user} do
      LookupStub.install(wikidata: :error, musicbrainz: :error)

      album =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{discogs_master_id: 24047},
          actor: user
        )

      assert album.spotify_album_id == nil
    end
  end

  test "a Spotify album link in the import search finds the album", %{user: user} do
    assert {:ok, results} =
             Records.lookup_albums("https://open.spotify.com/album/0ETFjACtuP2ADo6LFhL6HN?si=x",
               actor: user
             )

    assert [_ | _] = results
    assert Enum.all?(results, &(&1.spotify_album_id == "0ETFjACtuP2ADo6LFhL6HN"))
    assert Enum.any?(results, &(&1.title == "Abbey Road"))
  end

  test "a Spotify link unknown to Wikidata is resolved through MusicBrainz", %{user: user} do
    assert {:ok, [result]} =
             Records.lookup_albums("https://open.spotify.com/album/4gPYH4cFOgaukEpzcAr7vw",
               actor: user
             )

    assert result.artist_name == "The Oscar Peterson Trio"
    assert result.title == "Night Train"
    assert result.year == 1963
    assert result.spotify_album_id == "4gPYH4cFOgaukEpzcAr7vw"
  end
end
