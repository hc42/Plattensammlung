defmodule Plattensammlung.RecordsTest do
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.Records

  describe "add_to_collection" do
    test "creates album, artist and one copy" do
      album =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{
          year: 1969,
          copy: %{label: "Apple Records", media_condition: :very_good_plus}
        })

      album = Ash.load!(album, [:artist, :copies, :owned, :copy_count])

      assert to_string(album.artist.name) == "The Beatles"
      assert album.owned
      assert album.copy_count == 1
      refute album.wanted
      assert [%{label: "Apple Records", media_condition: :very_good_plus}] = album.copies
    end

    test "only artist and title are required" do
      assert {:ok, _} = Records.add_to_collection("Kraftwerk", "Autobahn")
      assert {:error, _} = Records.add_to_collection("Kraftwerk", nil)
      assert {:error, _} = Records.add_to_collection(nil, "Autobahn")
    end

    test "reuses an existing artist regardless of case" do
      first = Records.add_to_collection!("The Beatles", "Abbey Road")
      second = Records.add_to_collection!("the beatles", "Revolver")

      assert first.artist_id == second.artist_id
      assert length(Records.list_artists!()) == 1
    end
  end

  describe "wishlist" do
    test "an album on the wishlist is wanted but not owned" do
      album = Records.add_to_wishlist!("Can", "Tago Mago")
      album = Ash.load!(album, [:owned])

      assert album.wanted
      refute album.owned
      assert [%{id: id}] = Records.list_wishlist!()
      assert id == album.id
      assert Records.list_collection!() == []
    end

    test "adding a copy removes the album from the wishlist" do
      album = Records.add_to_wishlist!("Can", "Tago Mago")
      Records.add_copy!(album.id, %{format: "2LP"})

      assert Records.list_wishlist!() == []
      assert [%{id: id}] = Records.list_collection!()
      assert id == album.id
    end
  end

  describe "search_albums" do
    setup do
      Records.add_to_collection!("The Beatles", "Abbey Road")
      Records.add_to_collection!("Pink Floyd", "The Dark Side of the Moon")
      :ok
    end

    test "matches title or artist, case-insensitively" do
      assert titles(Records.search_albums!("abbey")) == ["Abbey Road"]
      assert titles(Records.search_albums!("FLOYD")) == ["The Dark Side of the Moon"]
      assert titles(Records.search_albums!("the")) == ["Abbey Road", "The Dark Side of the Moon"]
    end

    test "returns everything without a query" do
      assert length(Records.search_albums!()) == 2
    end
  end

  test "discogs_url is built from the stored id" do
    album = Records.add_to_collection!("The Beatles", "Abbey Road", %{discogs_master_id: 24047})

    assert Ash.load!(album, :discogs_url).discogs_url == "https://www.discogs.com/master/24047"
  end

  test "deleting an album deletes its copies" do
    album = Records.add_to_collection!("The Beatles", "Abbey Road")
    [copy] = Ash.load!(album, :copies).copies

    Records.destroy_album!(album)

    assert {:error, _} = Records.get_copy(copy.id)
  end

  defp titles(albums), do: Enum.map(albums, &to_string(&1.title))
end
