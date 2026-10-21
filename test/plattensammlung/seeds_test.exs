defmodule Plattensammlung.SeedsTest do
  use Plattensammlung.DataCase, async: true

  @moduletag :capture_log

  alias Plattensammlung.Records

  test "seeds create example albums for the first allowed user, once" do
    Code.eval_file("priv/repo/seeds.exs")
    Code.eval_file("priv/repo/seeds.exs")

    [owner] = Ash.read!(Plattensammlung.Accounts.User, authorize?: false)
    assert to_string(owner.email) == "test@example.com"

    albums = Records.search_albums!(nil, nil, actor: owner)
    assert length(albums) == 6
    assert Enum.all?(albums, &(&1.owner_id == owner.id))
  end
end
