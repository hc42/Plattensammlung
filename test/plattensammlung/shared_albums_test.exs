defmodule Plattensammlung.SharedAlbumsTest do
  @moduledoc "Albums are shared; copies and wishes belong to one user (ADR 0016)."
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.Records

  setup do
    alice = user_fixture()
    bob = user_fixture("bob@example.com")

    album =
      Records.add_to_collection!("The Beatles", "Abbey Road", %{year: 1969}, actor: alice)

    %{alice: alice, bob: bob, album: album}
  end

  describe "adding" do
    test "an album already in the catalog is reused, case-insensitively",
         %{bob: bob, album: album} do
      mine = Records.add_to_wishlist!("the beatles", "ABBEY ROAD", actor: bob)

      assert mine.id == album.id
      assert mine.wanted
      refute mine.owned
    end

    test "the Discogs id finds the album even under another title", %{alice: alice, bob: bob} do
      album =
        Records.add_to_collection!("Can", "Tago Mago", %{discogs_master_id: 4711}, actor: alice)

      mine =
        Records.add_to_collection!("CAN", "Tago Mago (Remastered)", %{discogs_master_id: 4711},
          actor: bob
        )

      assert mine.id == album.id
    end

    test "a reused album only gets missing values", %{bob: bob, album: album} do
      Records.add_to_collection!(
        "The Beatles",
        "Abbey Road",
        %{year: 2019, genres: ["Rock"]},
        actor: bob
      )

      assert %{year: 1969, genres: ["Rock"]} = Records.get_album!(album.id, actor: bob)
    end

    test "copies, counts and wishes are per user", %{alice: alice, bob: bob, album: album} do
      Records.add_to_collection!("The Beatles", "Abbey Road", actor: bob)
      Records.add_copy!(album.id, %{format: ["LP"]}, actor: bob)

      assert %{owned: true, copy_count: 1} =
               Records.get_album!(album.id, load: [:owned, :copy_count], actor: alice)

      assert %{owned: true, copy_count: 2} =
               Records.get_album!(album.id, load: [:owned, :copy_count], actor: bob)

      assert [_] = Records.list_collection!(actor: alice)
      assert [_] = Records.list_collection!(actor: bob)
    end

    test "an invalid copy leaves no new album behind", %{bob: bob} do
      assert {:error, _} =
               Records.add_to_collection("Kraftwerk", "Autobahn", %{copy: %{barcode: "123"}},
                 actor: bob
               )

      assert Records.find_duplicates!("Kraftwerk", "Autobahn", actor: bob) == []
    end
  end

  describe "changing" do
    test "everyone who has the album may change the shared data",
         %{alice: alice, bob: bob, album: album} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Records.update_album(album, %{year: 1970}, actor: bob)

      Records.mark_wanted!(album, actor: bob)
      assert {:ok, %{year: 1970}} = Records.update_album(album, %{year: 1970}, actor: bob)
      assert %{year: 1970} = Records.get_album!(album.id, actor: alice)
    end

    test "copies are changed only by their owner", %{bob: bob, album: album} do
      [copy] = Ash.load!(album, :copies, authorize?: false).copies

      assert {:error, %Ash.Error.Forbidden{}} =
               Records.update_copy(copy, %{label: "Apple"}, actor: bob)

      assert {:error, %Ash.Error.Forbidden{}} = Records.destroy_copy(copy, actor: bob)
    end

    test "a wish belongs to one user", %{alice: alice, bob: bob, album: album} do
      Records.mark_wanted!(album, actor: bob)

      refute Records.get_album!(album.id, load: [:wanted], actor: alice).wanted
      assert Records.get_album!(album.id, load: [:wanted], actor: bob).wanted

      # Wanting it twice changes nothing
      Records.mark_wanted!(album, actor: bob)
      assert [_] = Records.list_wishes!(actor: bob) |> Enum.filter(&(&1.owner_id == bob.id))
    end

    test "edit form checkbox sets only the own wish", %{alice: alice, bob: bob, album: album} do
      Records.update_album!(album, %{wanted: true}, actor: alice)
      Records.mark_wanted!(album, actor: bob)
      Records.update_album!(album, %{wanted: false}, actor: alice)

      refute Records.get_album!(album.id, load: [:wanted], actor: alice).wanted
      assert Records.get_album!(album.id, load: [:wanted], actor: bob).wanted
    end
  end

  describe "removing" do
    test "removing keeps the album for the others", %{alice: alice, bob: bob, album: album} do
      Records.mark_wanted!(album, actor: bob)

      Records.remove_album!(album.id, actor: alice)

      assert %{owned: false, wanted: false} =
               Records.get_album!(album.id, load: [:owned, :wanted], actor: alice)

      assert %{wanted: true} = Records.get_album!(album.id, load: [:wanted], actor: bob)
    end

    test "the album goes once the last holder removes it", %{alice: alice, bob: bob, album: album} do
      Records.mark_wanted!(album, actor: bob)
      Records.remove_album!(album.id, actor: alice)
      Records.remove_album!(album.id, actor: bob)

      assert {:error, _} = Records.get_album(album.id, actor: alice)
    end

    test "an album someone has can't be deleted directly", %{bob: bob, album: album} do
      assert {:error, %Ash.Error.Forbidden{}} = Records.destroy_album(album, actor: bob)
    end
  end
end
