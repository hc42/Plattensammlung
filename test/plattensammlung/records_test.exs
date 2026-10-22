defmodule Plattensammlung.RecordsTest do
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.Records

  setup do
    %{user: user_fixture()}
  end

  describe "authorization" do
    test "every action needs a signed-in user (actor)" do
      # Refused either way: no owner to relate (invalid) or forbidden by policy
      assert {:error, error} = Records.add_to_collection("Kraftwerk", "Autobahn")
      assert error.class in [:forbidden, :invalid]
      assert {:error, %Ash.Error.Forbidden{}} = Records.search_albums(nil, nil)
      assert {:error, %Ash.Error.Forbidden{}} = Records.lookup_albums("beatles")
    end
  end

  describe "add_to_collection" do
    test "creates album, artist and one copy", %{user: user} do
      album =
        Records.add_to_collection!(
          "The Beatles",
          "Abbey Road",
          %{year: 1969, copy: %{label: "Apple Records", media_condition: :very_good_plus}},
          actor: user
        )

      album = Ash.load!(album, [:artist, :copies, :owned, :copy_count], actor: user)

      assert to_string(album.artist.name) == "The Beatles"
      assert album.owned
      assert album.copy_count == 1
      refute album.wanted
      assert [%{label: "Apple Records", media_condition: :very_good_plus}] = album.copies
    end

    test "only artist and title are required", %{user: user} do
      assert {:ok, _} = Records.add_to_collection("Kraftwerk", "Autobahn", actor: user)
      assert {:error, _} = Records.add_to_collection("Kraftwerk", nil, actor: user)
      assert {:error, _} = Records.add_to_collection(nil, "Autobahn", actor: user)
    end

    test "reuses an existing artist regardless of case", %{user: user} do
      first = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
      second = Records.add_to_collection!("the beatles", "Revolver", actor: user)

      assert first.artist_id == second.artist_id
      assert length(Records.list_artists!(actor: user)) == 1
    end
  end

  describe "wishlist" do
    test "an album on the wishlist is wanted but not owned", %{user: user} do
      album = Records.add_to_wishlist!("Can", "Tago Mago", actor: user)
      album = Ash.load!(album, [:owned], actor: user)

      assert album.wanted
      refute album.owned
      assert [%{id: id}] = Records.list_wishlist!(actor: user)
      assert id == album.id
      assert Records.list_collection!(actor: user) == []
    end

    test "adding a copy removes the album from the wishlist", %{user: user} do
      album = Records.add_to_wishlist!("Can", "Tago Mago", actor: user)
      Records.add_copy!(album.id, %{format: ["2LP"]}, actor: user)

      assert Records.list_wishlist!(actor: user) == []
      assert [%{id: id}] = Records.list_collection!(actor: user)
      assert id == album.id
    end
  end

  describe "search_albums" do
    setup %{user: user} do
      Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
      Records.add_to_collection!("Pink Floyd", "The Dark Side of the Moon", actor: user)
      :ok
    end

    test "matches title or artist, case-insensitively", %{user: user} do
      assert titles(Records.search_albums!("abbey", nil, actor: user)) == ["Abbey Road"]

      assert titles(Records.search_albums!("FLOYD", nil, actor: user)) == [
               "The Dark Side of the Moon"
             ]

      assert titles(Records.search_albums!("the", nil, actor: user)) ==
               ["Abbey Road", "The Dark Side of the Moon"]
    end

    test "returns everything without a query", %{user: user} do
      assert length(Records.search_albums!(nil, nil, actor: user)) == 2
    end
  end

  test "discogs_url is built from the stored id", %{user: user} do
    album =
      Records.add_to_collection!("The Beatles", "Abbey Road", %{discogs_master_id: 24047},
        actor: user
      )

    assert Ash.load!(album, :discogs_url, actor: user).discogs_url ==
             "https://www.discogs.com/master/24047"
  end

  test "removing an album deletes the own copies and the album no one has", %{user: user} do
    album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
    [copy] = Ash.load!(album, :copies, actor: user).copies

    Records.remove_album!(album.id, actor: user)

    assert {:error, _} = Records.get_copy(copy.id, actor: user)
    assert {:error, _} = Records.get_album(album.id, actor: user)
  end

  defp titles(albums), do: Enum.map(albums, &to_string(&1.title))
end
