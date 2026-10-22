defmodule Plattensammlung.MergeAlbumsTest do
  use Plattensammlung.DataCase, async: true

  alias Plattensammlung.Records

  setup do
    alice = user_fixture("alice@example.com")
    bob = user_fixture("bob@example.com")
    carol = user_fixture("carol@example.com")

    # Two catalogue entries for the same record, e.g. from two imports
    target = Records.create_album!("Can", %{title: "Tago Mago"}, actor: alice)

    source =
      Records.create_album!(
        "CAN",
        %{title: "Tago Mago (Remaster)", year: 1971, genres: ["Krautrock"]},
        actor: bob
      )

    %{alice: alice, bob: bob, carol: carol, target: target, source: source}
  end

  defp holders(album_id) do
    album = Records.get_album!(album_id, load: [:copies, :wishes], authorize?: false)

    {Enum.map(album.copies, & &1.owner_id) |> Enum.sort(),
     Enum.map(album.wishes, & &1.owner_id) |> Enum.sort()}
  end

  test "copies and wishes of everyone move, gaps are filled, the duplicate goes", ctx do
    Records.add_copy!(ctx.target.id, %{}, actor: ctx.alice)
    Records.add_copy!(ctx.source.id, %{label: "United Artists"}, actor: ctx.bob)
    Records.add_wish!(ctx.source.id, actor: ctx.carol)
    # Alice wants the duplicate too, but already has the target: her wish goes
    Records.add_wish!(ctx.source.id, actor: ctx.alice)

    assert {:ok, merged} = Records.merge_albums(ctx.source.id, ctx.target.id, actor: ctx.alice)

    assert merged.id == ctx.target.id
    assert to_string(merged.title) == "Tago Mago"
    assert merged.year == 1971
    assert merged.genres == ["Krautrock"]

    assert holders(ctx.target.id) ==
             {Enum.sort([ctx.alice.id, ctx.bob.id]), [ctx.carol.id]}

    assert {:error, _} = Records.get_album(ctx.source.id, authorize?: false)
  end

  test "a copy that moves ends its owner's wish on the remaining album", ctx do
    Records.add_wish!(ctx.target.id, actor: ctx.bob)
    Records.add_copy!(ctx.source.id, %{}, actor: ctx.bob)

    assert {:ok, _} = Records.merge_albums(ctx.source.id, ctx.target.id, actor: ctx.bob)
    assert holders(ctx.target.id) == {[ctx.bob.id], []}
  end

  test "whoever has one of the two may merge, others may not", ctx do
    Records.add_copy!(ctx.target.id, %{}, actor: ctx.alice)
    Records.add_copy!(ctx.source.id, %{}, actor: ctx.bob)

    assert {:error, %Ash.Error.Forbidden{}} =
             Records.merge_albums(ctx.source.id, ctx.target.id, actor: ctx.carol)

    # Bob has only the duplicate and still may merge it into Alice's album
    assert {:ok, _} = Records.merge_albums(ctx.source.id, ctx.target.id, actor: ctx.bob)
  end

  test "albums nobody has may be merged by anyone", ctx do
    assert {:ok, _} = Records.merge_albums(ctx.source.id, ctx.target.id, actor: ctx.carol)
  end

  test "the cover of the duplicate moves over if the remaining album has none", ctx do
    # As if the app had stored it (local paths are only set by the app)
    ctx.source
    |> Ash.Changeset.for_update(:absorb, %{cover_url: "/covers/tago.jpg"}, authorize?: false)
    |> Ash.update!()

    assert {:ok, %{cover_url: "/covers/tago.jpg"}} =
             Records.merge_albums(ctx.source.id, ctx.target.id, actor: ctx.alice)
  end

  test "an album can't be merged with itself", ctx do
    assert {:error, %Ash.Error.Invalid{}} =
             Records.merge_albums(ctx.target.id, ctx.target.id, actor: ctx.alice)
  end
end
