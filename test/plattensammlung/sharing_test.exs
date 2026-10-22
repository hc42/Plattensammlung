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

  test "collection and wishlist are the actor's own, the catalog is shared",
       %{alice: alice, bob: bob} do
    assert [_] = Records.list_collection!(actor: alice)
    assert [_] = Records.list_wishlist!(actor: alice)
    assert Records.list_collection!(actor: bob) == []
    assert Records.search_albums!(nil, :collection, actor: bob) == []
    assert length(Records.search_albums!(nil, nil, actor: bob)) == 2
  end

  test "everyone signed in can look at other collections", %{alice: alice, bob: bob, album: album} do
    assert [%{title: title}] =
             Records.search_albums!(nil, :collection, %{owner_id: alice.id}, actor: bob)

    assert to_string(title) == "Abbey Road"
    assert [_] = Records.search_albums!(nil, :wishlist, %{owner_id: alice.id}, actor: bob)
    assert {:ok, _} = Records.get_album(album.id, actor: bob)
  end

  test "others may not change an album they don't have, nor someone's copies",
       %{bob: bob, album: album} do
    [copy] = Ash.load!(album, :copies, authorize?: false).copies

    assert {:error, %Ash.Error.Forbidden{}} =
             Records.update_album(album, %{year: 1999}, actor: bob)

    assert {:error, %Ash.Error.Forbidden{}} = Records.destroy_album(album, actor: bob)

    assert {:error, %Ash.Error.Forbidden{}} =
             Records.update_copy(copy, %{notes: "meins"}, actor: bob)

    # An own copy of the shared album is fine
    assert {:ok, %{owner_id: owner_id}} = Records.add_copy(album.id, %{}, actor: bob)
    assert owner_id == bob.id
  end

  test "an album nobody has may be changed by anyone, like it may be deleted",
       %{alice: alice, bob: bob} do
    album = Records.add_to_wishlist!("Can", "Ege Bamyasi", actor: alice)
    album = Records.get_album!(album.id, load: [:editable], actor: bob)
    refute album.editable

    assert {:error, %Ash.Error.Forbidden{}} =
             Records.update_album(album, %{year: 1972}, actor: bob)

    # Alice takes it off her wishlist: now nobody has it
    Records.unmark_wanted!(album, actor: alice)
    album = Records.get_album!(album.id, load: [:editable], actor: bob)

    assert album.editable
    assert {:ok, %{year: 1972}} = Records.update_album(album, %{year: 1972}, actor: bob)
  end

  test "purchase date and notes of a copy are readable by the owner only",
       %{alice: alice, bob: bob, album: album} do
    [copy] = Ash.load!(album, :copies, authorize?: false).copies

    Records.update_copy!(copy, %{notes: "Geheim", purchased_on: ~D[2019-05-03], label: "Apple"},
      actor: alice
    )

    theirs = Records.get_copy!(copy.id, actor: bob)
    assert theirs.label == "Apple"
    assert %Ash.ForbiddenField{} = theirs.notes
    assert %Ash.ForbiddenField{} = theirs.purchased_on

    assert [%{notes: %Ash.ForbiddenField{}}] =
             Records.get_album!(album.id, load: [:copies], actor: bob).copies

    mine = Records.get_copy!(copy.id, actor: alice)
    assert mine.notes == "Geheim"
    assert mine.purchased_on == ~D[2019-05-03]
  end

  test "statistics describe one collection", %{alice: alice, bob: bob} do
    assert %{albums: 0, wishlist: 0} = Records.statistics!(actor: bob)
    assert %{albums: 1, wishlist: 1} = Records.statistics!(%{owner_id: alice.id}, actor: bob)
  end

  test "duplicates are found in the whole catalog, adding reuses them",
       %{bob: bob, album: album} do
    assert [%{id: id}] = Records.find_duplicates!("The Beatles", "Abbey Road", actor: bob)
    assert id == album.id
    assert {:ok, %{id: ^id}} = Records.add_to_collection("The Beatles", "Abbey Road", actor: bob)
  end

  describe "collectors" do
    test "show names but never e-mail addresses", %{alice: alice, bob: bob} do
      Accounts.update_profile!(alice, "Alice", actor: alice)

      collectors = Accounts.list_collectors!(actor: bob)

      assert MapSet.new(collectors, & &1.display_name) == MapSet.new(["Alice", nil])

      # The e-mail is not even read from the database
      assert Enum.all?(collectors, &match?(%Ash.NotLoaded{}, &1.email))
    end

    test "only oneself can change the own profile", %{alice: alice, bob: bob} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.update_profile(alice, "Bob war hier", actor: bob)
    end
  end
end
