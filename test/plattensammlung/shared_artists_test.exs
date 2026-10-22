defmodule Plattensammlung.SharedArtistsTest do
  @moduledoc "Artists are shared: no one changes what others have albums of (ADR 0015)."
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.Records
  alias Plattensammlung.Records.ArtistCleanup

  setup do
    alice = user_fixture()
    bob = user_fixture("bob@example.com")
    album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: alice)
    artist = Records.get_artist!(album.artist_id, actor: alice)

    %{alice: alice, bob: bob, album: album, artist: artist}
  end

  test "an artist someone else has albums of can't be renamed or deleted",
       %{bob: bob, artist: artist} do
    assert {:error, %Ash.Error.Forbidden{}} =
             Records.update_artist(artist, %{name: "Die Käfer"}, actor: bob)

    # Refused either way: the album check runs before the policy
    assert {:error, _} = Records.destroy_artist(artist, actor: bob)
    assert {:ok, _} = Records.get_artist(artist.id, actor: bob)
  end

  test "the only user with albums of an artist may rename it, not delete it",
       %{alice: alice, artist: artist} do
    assert {:ok, %{name: name}} =
             Records.update_artist(artist, %{sort_name: "Beatles, The"}, actor: alice)

    assert to_string(name) == "The Beatles"

    assert {:error, %Ash.Error.Invalid{}} = Records.destroy_artist(artist, actor: alice)
  end

  test "once Bob has the album too, Alice can't rename the artist either",
       %{alice: alice, bob: bob, album: album, artist: artist} do
    Records.mark_wanted!(album, actor: bob)

    assert {:error, %Ash.Error.Forbidden{}} =
             Records.update_artist(artist, %{name: "Die Käfer"}, actor: alice)
  end

  test "the artist goes with the last album, not before",
       %{alice: alice, bob: bob, album: album, artist: artist} do
    Records.mark_wanted!(album, actor: bob)

    # Bob still wants the album, so album and artist stay
    Records.remove_album!(album.id, actor: alice)
    assert {:ok, _} = Records.get_artist(artist.id, actor: bob)

    Records.remove_album!(album.id, actor: bob)
    assert {:error, _} = Records.get_artist(artist.id, actor: bob)
  end

  test "moving an album to another artist removes the unused one",
       %{alice: alice, album: album, artist: artist} do
    Records.update_album!(album, %{artist_name: "Beatles"}, actor: alice)

    assert {:error, _} = Records.get_artist(artist.id, actor: alice)
  end

  test "leftover artists are cleaned up", %{alice: alice, artist: artist} do
    orphan = Records.create_artist!("Nobody", actor: alice)

    assert :ok = ArtistCleanup.cleanup_orphans()

    assert {:error, _} = Records.get_artist(orphan.id, actor: alice)
    assert {:ok, _} = Records.get_artist(artist.id, actor: alice)
  end
end
