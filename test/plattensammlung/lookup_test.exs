defmodule Plattensammlung.LookupTest do
  use Plattensammlung.DataCase, async: true

  # Failure scenarios log warnings on purpose
  @moduletag :capture_log

  alias Plattensammlung.{Covers, Lookup, LookupStub, Records}
  alias Plattensammlung.Records.LookupResult

  describe "barcode lookup" do
    test "resolves a Discogs pressing to its album" do
      LookupStub.install()

      assert {:ok, [%LookupResult{} = result]} =
               Records.lookup_albums(LookupStub.abbey_road_barcode())

      assert result.source == :discogs
      assert result.artist_name == "The Beatles"
      assert result.title == "Abbey Road"
      # Album data comes from the master, pressing data from the release
      assert result.year == 1969
      assert result.pressing_year == 2019
      assert result.discogs_master_id == 24047
      assert result.discogs_release_id == 12_345_678
      assert result.label == "Apple Records"
      assert result.format == "Vinyl, LP, Album"
      assert result.barcode == LookupStub.abbey_road_barcode()
    end

    test "accepts spaces and dashes in the barcode" do
      LookupStub.install()

      assert {:ok, [_result]} = Records.lookup_albums("0 602547 288530")
      assert Lookup.barcode("0-602547-288530") == "0602547288530"
      assert Lookup.barcode("Abbey Road 1969") == nil
    end

    test "falls back to MusicBrainz when Discogs knows nothing" do
      LookupStub.install(discogs: :empty)

      assert {:ok, [result]} = Records.lookup_albums(LookupStub.abbey_road_barcode())
      assert result.source == :musicbrainz
      assert result.musicbrainz_release_group_id == "9162580e-5df4-32de-80cc-f45a8d8a9b1d"
      assert result.label == "Apple"
      assert result.format == "12\" Vinyl"
    end

    test "falls back to MusicBrainz when Discogs fails" do
      LookupStub.install(discogs: :error)

      assert {:ok, [%{source: :musicbrainz}]} =
               Records.lookup_albums(LookupStub.abbey_road_barcode())
    end

    test "returns an error when every source fails" do
      LookupStub.install(discogs: :error, musicbrainz: :error)

      assert {:error, _} = Records.lookup_albums(LookupStub.abbey_road_barcode())
    end
  end

  describe "text lookup" do
    test "merges both sources and drops the same album from MusicBrainz" do
      LookupStub.install()

      assert {:ok, results} = Records.lookup_albums("beatles abbey road")

      assert Enum.map(results, &{&1.source, &1.title}) == [
               {:discogs, "Abbey Road"},
               {:musicbrainz, "Abbey Road Revisited"}
             ]

      assert List.last(results).artist_name == "Various & Friends"
    end

    test "still returns results when one source fails" do
      LookupStub.install(discogs: :error)

      assert {:ok, [_, _]} = Records.lookup_albums("beatles abbey road")
    end
  end

  describe "covers" do
    test "a remote cover is downloaded and served locally" do
      LookupStub.install()

      album =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{
          cover_url: "https://i.discogs.com/master.jpg"
        })

      assert "/covers/" <> file = album.cover_url
      assert String.ends_with?(file, ".jpg")
      path = Path.join(Covers.dir(), file)
      assert File.read!(path) == "fake-jpeg-bytes"

      Records.destroy_album!(album)
      refute File.exists?(path)
    end

    test "replacing a cover deletes the old file" do
      LookupStub.install()
      album = Records.add_to_collection!("Can", "Tago Mago", %{cover_url: "https://x.test/a.jpg"})
      old_path = Path.join(Covers.dir(), Path.basename(album.cover_url))

      album = Records.update_album!(album, %{cover_url: "https://x.test/b.jpg"})

      refute File.exists?(old_path)
      assert File.exists?(Path.join(Covers.dir(), Path.basename(album.cover_url)))
    end

    test "a failed download keeps the remote URL" do
      Req.Test.stub(Plattensammlung.Lookup, &Plug.Conn.send_resp(&1, 404, ""))

      album = Records.add_to_collection!("Can", "Tago Mago", %{cover_url: "https://x.test/a.jpg"})

      assert album.cover_url == "https://x.test/a.jpg"
    end
  end

  test "find_by_barcode finds albums owning that pressing" do
    album = Records.add_to_collection!("The Beatles", "Abbey Road", %{copy: %{barcode: "123"}})

    assert [%{id: id}] = Records.find_by_barcode!("123")
    assert id == album.id
    assert Records.find_by_barcode!("456") == []
  end
end
