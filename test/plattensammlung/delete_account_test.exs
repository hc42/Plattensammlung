defmodule Plattensammlung.DeleteAccountTest do
  use Plattensammlung.DataCase, async: true

  require Ash.Query

  alias Plattensammlung.{Accounts, Records}

  setup do
    alice = user_fixture("alice@example.com")
    bob = user_fixture("bob@example.com")

    only_alice = Records.add_to_collection!("Can", "Tago Mago", actor: alice)
    shared = Records.add_to_collection!("The Beatles", "Abbey Road", actor: alice)
    Records.add_to_collection!("The Beatles", "Abbey Road", actor: bob)
    wish = Records.add_to_wishlist!("Kraftwerk", "Autobahn", actor: alice)
    api_key_fixture(alice)

    %{alice: alice, bob: bob, only_alice: only_alice, shared: shared, wish: wish}
  end

  test "deletes the user with their copies, wishes and keys; shared albums stay", ctx do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(ctx.alice)
    assert token

    assert :ok = Accounts.delete_account(ctx.alice, actor: ctx.alice)

    assert {:error, _} = Accounts.get_user(ctx.alice.id, authorize?: false)

    # Albums nobody else has are gone, the shared one keeps Bob's copy
    assert {:error, _} = Records.get_album(ctx.only_alice.id, authorize?: false)
    assert {:error, _} = Records.get_album(ctx.wish.id, authorize?: false)

    assert %{copies: [%{owner_id: bob_id}]} =
             Records.get_album!(ctx.shared.id, load: [:copies], authorize?: false)

    assert bob_id == ctx.bob.id

    assert Plattensammlung.Accounts.ApiKey |> Ash.read!(authorize?: false) == []

    subject = AshAuthentication.user_to_subject(ctx.alice)

    assert Plattensammlung.Accounts.Token
           |> Ash.Query.filter(subject == ^subject)
           |> Ash.read!(authorize?: false) == []
  end

  test "nobody can delete someone else's account", %{alice: alice, bob: bob} do
    assert {:error, %Ash.Error.Forbidden{}} = Accounts.delete_account(alice, actor: bob)
    assert {:ok, _} = Accounts.get_user(alice.id, authorize?: false)
  end
end
