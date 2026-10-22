defmodule Plattensammlung.SeedsTest do
  use Plattensammlung.DataCase, async: true

  @moduletag :capture_log

  alias Plattensammlung.Records

  test "seeds create example albums for the first allowed user, once" do
    Code.eval_file("priv/repo/seeds.exs")
    Code.eval_file("priv/repo/seeds.exs")

    [owner] = Ash.read!(Plattensammlung.Accounts.User, authorize?: false)
    assert to_string(owner.email) == "test@example.com"

    assert length(Records.list_collection!(actor: owner)) == 4
    assert length(Records.list_wishlist!(actor: owner)) == 2
  end
end
