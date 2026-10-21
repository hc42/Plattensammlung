defmodule Plattensammlung.SharingTest do
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.{Accounts, Records}

  setup do
    alice = user_fixture()
    bob = user_fixture("bob@example.com")

    album =
      Records.add_to_collection!("The Beatles", "Abbey Road", %{genres: ["Rock"]}, actor: alice)

    Records.add_to_wishlist!("Can", "Tago Mago", actor: alice)

    %{alice: alice, bob: bob, album: album}
  end

  test "lists show the actor's own albums by default", %{alice: alice, bob: bob} do
    assert length(Records.search_albums!(nil, nil, actor: alice)) == 2
    assert Records.search_albums!(nil, nil, actor: bob) == []
  end

  test "everyone signed in can look at other collections", %{alice: alice, bob: bob, album: album} do
    assert [%{title: title}] =
             Records.search_albums!(nil, :collection, %{owner_id: alice.id}, actor: bob)

    assert to_string(title) == "Abbey Road"
    assert [_] = Records.search_albums!(nil, :wishlist, %{owner_id: alice.id}, actor: bob)
    assert {:ok, _} = Records.get_album(album.id, actor: bob)
  end

  test "only the owner changes an album and its copies", %{bob: bob, album: album} do
    [copy] = Ash.load!(album, :copies, authorize?: false).copies

    assert {:error, %Ash.Error.Forbidden{}} =
             Records.update_album(album, %{year: 1999}, actor: bob)

    assert {:error, %Ash.Error.Forbidden{}} = Records.destroy_album(album, actor: bob)
    assert {:error, %Ash.Error.Forbidden{}} = Records.add_copy(album.id, %{}, actor: bob)

    assert {:error, %Ash.Error.Forbidden{}} =
             Records.update_copy(copy, %{notes: "meins"}, actor: bob)
  end

  test "statistics describe one collection", %{alice: alice, bob: bob} do
    assert %{albums: 0, wishlist: 0} = Records.statistics!(actor: bob)
    assert %{albums: 1, wishlist: 1} = Records.statistics!(%{owner_id: alice.id}, actor: bob)
  end

  test "duplicates are checked in the own collection only", %{bob: bob} do
    assert Records.find_duplicates!("The Beatles", "Abbey Road", actor: bob) == []
    # So Bob can have his own Abbey Road
    assert {:ok, _} = Records.add_to_collection("The Beatles", "Abbey Road", actor: bob)
  end

  describe "collectors" do
    test "show names but never e-mail addresses", %{alice: alice, bob: bob} do
      Accounts.update_profile!(alice, "Alice", actor: alice)

      collectors = Accounts.list_collectors!(actor: bob)

      assert Enum.map(collectors, &Accounts.display_name/1) |> Enum.sort() == [
               "Alice",
               "Ohne Namen"
             ]

      # The e-mail is not even read from the database
      assert Enum.all?(collectors, &match?(%Ash.NotLoaded{}, &1.email))
    end

    test "only oneself can change the own profile", %{alice: alice, bob: bob} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_profile(alice, "Bob war hier", actor: bob)
    end
  end
end
