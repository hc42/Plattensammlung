defmodule Plattensammlung.AlbumMatchTest do
  use Plattensammlung.DataCase, async: true

  @moduletag :capture_log

  alias Plattensammlung.{Covers, LookupStub, Records}
  alias Plattensammlung.Records.{AlbumMatch, LookupResult}

  setup do
    LookupStub.install()
    %{user: user_fixture()}
  end

  describe "AlbumMatch.changes/3" do
    setup do
      album = %{
        year: 1969,
        genres: [],
        cover_url: "https://coverartarchive.org/failed-download.jpg",
        discogs_master_id: nil,
        musicbrainz_release_group_id: nil
      }

      result = %LookupResult{
        year: 2019,
        genres: ["Rock"],
        cover_url: "https://i.discogs.com/new.jpg",
        discogs_master_id: 24047
      }

      %{album: album, result: result}
    end

    test "fill only touches empty fields; a remote cover counts as empty", ctx do
      assert AlbumMatch.changes(ctx.album, ctx.result, :fill) == %{
               genres: ["Rock"],
               cover_url: "https://i.discogs.com/new.jpg",
               discogs_master_id: 24047
             }
    end

    test "overwrite takes everything the result has", ctx do
      changes = AlbumMatch.changes(ctx.album, ctx.result, :overwrite)

      assert changes.year == 2019
      assert AlbumMatch.labels(changes) == ["Cover", "Discogs-Verknüpfung", "Genres", "Jahr"]
    end
  end

  describe "find_matches" do
    test "fetches a linked album directly by its ids", %{user: user} do
      album =
        Records.add_to_collection!(
          "The Beatles",
          "Abbey Road",
          %{
            discogs_master_id: 24047,
            musicbrainz_release_group_id: "9162580e-5df4-32de-80cc-f45a8d8a9b1d"
          },
          actor: user
        )

      assert {:ok, [discogs, musicbrainz]} = Records.find_matches(album.id, nil, actor: user)
      assert discogs.source == :discogs
      assert discogs.year == 1969
      assert musicbrainz.genres == ["Rock", "Art Rock", "Pop"]
    end

    test "searches artist and title when the album is not linked", %{user: user} do
      album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)

      assert {:ok, [_, _]} = Records.find_matches(album.id, nil, actor: user)
    end

    test "uses the given query instead", %{user: user} do
      album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)

      assert {:ok, [%{barcode: "0602547288530"}]} =
               Records.find_matches(album.id, "0602547288530", actor: user)
    end
  end

  test "apply_match fills the album and downloads the cover", %{user: user} do
    album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
    {:ok, [result | _]} = Records.find_matches(album.id, nil, actor: user)

    album = Records.apply_match!(album, result, :fill, actor: user)

    assert album.year == 1969
    assert album.genres == ["Rock", "Pop"]
    assert album.discogs_master_id == 24047
    assert "/covers/" <> _ = album.cover_url
    # Artist and title stay as entered
    assert to_string(album.title) == "Abbey Road"
  end

  describe "pressing details from a barcode" do
    setup %{user: user} do
      album =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{copy: %{notes: "Regal B"}},
          actor: user
        )

      {:ok, [result]} =
        Records.find_matches(album.id, LookupStub.abbey_road_barcode(), actor: user)

      [copy] = Ash.load!(album, :copies, actor: user).copies

      %{album: album, result: result, copy: copy}
    end

    test "fill an existing copy, keeping what is already there", ctx do
      Records.apply_match!(ctx.album, ctx.result, :fill, %{copy_id: ctx.copy.id}, actor: ctx.user)

      copy = Records.get_copy!(ctx.copy.id, actor: ctx.user)
      assert copy.barcode == "0602547288530"
      assert copy.label == "Apple Records"
      assert copy.discogs_release_id == 12_345_678
      assert copy.notes == "Regal B"
    end

    test "or go into a new copy", ctx do
      Records.apply_match!(ctx.album, ctx.result, :fill, %{new_copy: true}, actor: ctx.user)

      copies = Ash.load!(ctx.album, :copies, actor: ctx.user).copies
      assert length(copies) == 2
      assert Enum.any?(copies, &(&1.barcode == "0602547288530"))
    end

    test "a copy of another album is refused", ctx do
      other = Records.add_to_collection!("Can", "Tago Mago", actor: ctx.user)
      [other_copy] = Ash.load!(other, :copies, actor: ctx.user).copies

      assert {:error, _} =
               Records.apply_match(ctx.album, ctx.result, :fill, %{copy_id: other_copy.id},
                 actor: ctx.user
               )

      assert Records.get_copy!(other_copy.id, actor: ctx.user).barcode == nil
    end
  end

  describe "covers" do
    @png <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, "rest-of-image">>

    test "an uploaded image replaces the cover; removing deletes the file", %{user: user} do
      album =
        Records.add_to_collection!("Can", "Tago Mago", %{cover_url: "https://x.test/a.jpg"},
          actor: user
        )

      old_path = Path.join(Covers.dir(), Path.basename(album.cover_url))

      album = Records.upload_cover!(album, upload(@png), actor: user)

      assert String.ends_with?(album.cover_url, ".png")
      refute File.exists?(old_path)
      new_path = Path.join(Covers.dir(), Path.basename(album.cover_url))
      assert File.read!(new_path) == @png

      album = Records.remove_cover!(album, actor: user)
      assert album.cover_url == nil
      refute File.exists?(new_path)
    end

    test "files that are not images are rejected", %{user: user} do
      album = Records.add_to_collection!("Can", "Tago Mago", actor: user)

      assert {:error, error} = Records.upload_cover(album, upload("<html>"), actor: user)
      assert Exception.message(error) =~ "must be a JPEG, PNG, WebP or GIF image"
    end

    defp upload(content) do
      path = Path.join(System.tmp_dir!(), "upload-#{System.unique_integer([:positive])}")
      File.write!(path, content)
      on_exit(fn -> File.rm(path) end)
      Ash.Type.File.from_path(path)
    end
  end
end
