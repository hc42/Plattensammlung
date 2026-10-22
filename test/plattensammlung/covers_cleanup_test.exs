defmodule Plattensammlung.CoversCleanupTest do
  # Not async: works on the shared covers directory
  use Plattensammlung.DataCase, async: false

  @moduletag :capture_log

  alias Plattensammlung.{Covers, LookupStub, Records}

  setup do
    LookupStub.install()
    File.mkdir_p!(Covers.dir())
    %{user: user_fixture()}
  end

  test "deletes old files no album refers to, keeps the rest", %{user: user} do
    album =
      Records.add_to_collection!("Can", "Tago Mago", %{cover_url: "https://x.test/a.jpg"},
        actor: user
      )

    referenced = Path.basename(album.cover_url)
    make_old(referenced)

    orphan = write_cover("orphan.jpg") |> make_old()
    fresh = write_cover("fresh.jpg")

    assert {:ok, deleted} = Covers.cleanup_orphans()

    assert orphan in deleted
    refute File.exists?(Path.join(Covers.dir(), orphan))
    assert File.exists?(Path.join(Covers.dir(), referenced))
    # Younger than an hour: could be an upload in progress
    assert File.exists?(Path.join(Covers.dir(), fresh))
  end

  test "deleting the album no one has removes its cover after the commit", %{user: user} do
    album =
      Records.add_to_collection!("Can", "Tago Mago", %{cover_url: "https://x.test/a.jpg"},
        actor: user
      )

    path = Path.join(Covers.dir(), Path.basename(album.cover_url))

    Records.remove_album!(album.id, actor: user)

    refute File.exists?(path)
  end

  defp write_cover(name) do
    name = "#{System.unique_integer([:positive])}-#{name}"
    File.write!(Path.join(Covers.dir(), name), "image")
    on_exit(fn -> File.rm(Path.join(Covers.dir(), name)) end)
    name
  end

  defp make_old(name) do
    two_hours_ago = System.os_time(:second) - 7200
    File.touch!(Path.join(Covers.dir(), name), two_hours_ago)
    name
  end
end
