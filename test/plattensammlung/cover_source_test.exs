defmodule Plattensammlung.CoverSourceTest do
  @moduledoc "Cover URLs from input must come from a known cover host (ADR 0014)."
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.{Covers, LookupStub, Records}
  alias Plattensammlung.Records.LookupResult

  setup do
    LookupStub.install()
    alice = user_fixture()
    bob = user_fixture("bob@example.com")

    album =
      Records.add_to_collection!("Can", "Tago Mago", %{cover_url: "https://i.discogs.com/a.jpg"},
        actor: alice
      )

    # Downloaded by the stub
    assert "/covers/" <> _ = album.cover_url

    %{alice: alice, bob: bob, album: album}
  end

  test "someone else's cover file cannot be taken over and deleted",
       %{bob: bob, album: album} do
    path = Path.join(Covers.dir(), Path.basename(album.cover_url))

    assert {:error, %Ash.Error.Invalid{}} =
             Records.add_to_collection("A", "B", %{cover_url: album.cover_url}, actor: bob)

    assert {:error, %Ash.Error.Invalid{}} =
             Records.add_to_wishlist("A", "B", %{cover_url: album.cover_url}, actor: bob)

    own = Records.add_to_wishlist!("A", "B", actor: bob)

    assert {:error, %Ash.Error.Invalid{}} =
             Records.update_album(own, %{cover_url: album.cover_url}, actor: bob)

    result = %LookupResult{title: "B", cover_url: album.cover_url}

    assert {:error, %Ash.Error.Invalid{}} =
             Records.apply_match(own, result, :overwrite, actor: bob)

    assert File.exists?(path)
  end

  test "covers from other hosts are rejected", %{bob: bob} do
    for url <- ["http://i.discogs.com/a.jpg", "https://192.168.1.1/cam.jpg", "javascript:x"] do
      assert {:error, %Ash.Error.Invalid{}} =
               Records.add_to_wishlist("A", "B", %{cover_url: url}, actor: bob)
    end
  end

  test "an unchanged local cover does not block other edits", %{alice: alice, album: album} do
    assert {:ok, _} = Records.update_album(album, %{year: 1971}, actor: alice)
  end

  test "the shared cover stays while someone still has the album",
       %{alice: alice, bob: bob, album: album} do
    path = Path.join(Covers.dir(), Path.basename(album.cover_url))
    Records.mark_wanted!(album, actor: bob)

    Records.remove_album!(album.id, actor: bob)
    assert File.exists?(path)

    Records.remove_album!(album.id, actor: alice)
    refute File.exists?(path)
  end
end
