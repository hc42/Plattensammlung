defmodule PlattensammlungWeb.SignInLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  test "pages need a signed-in user", %{conn: conn} do
    for path <- [~p"/", ~p"/wishlist", ~p"/import", ~p"/account"] do
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, path)
    end
  end

  test "requesting a magic link mails it and confirms", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/sign-in")
    assert has_element?(view, "#passkey-sign-in")

    view |> form("#magic-link-form", email: "test@example.com") |> render_submit()

    assert has_element?(view, "#magic-link-sent")
    assert_email_sent(fn email -> assert email.html_body =~ "http://www.example.com" end)
  end

  test "signed-in users are sent to the collection", %{conn: conn} do
    %{conn: conn} = register_and_sign_in_user(%{conn: conn})

    assert {:error, {:redirect, %{to: "/"}}} = live(conn, ~p"/sign-in")
  end

  describe "account page" do
    setup :register_and_sign_in_user

    test "creates an API key and shows it once", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/account")

      view |> form("#api-key-form", valid_for: "30") |> render_submit()

      assert view |> element("#new-api-key code") |> render() =~ "plattensammlung_"
      assert has_element?(view, "#api-keys li[id^=api-key-]")
    end

    test "deleting the account needs the own e-mail address", %{conn: conn, user: user} do
      Plattensammlung.Records.add_to_collection!("Can", "Tago Mago", actor: user)
      {:ok, view, _html} = live(conn, ~p"/account")

      view |> form("#delete-account-form", email: "someone@example.com") |> render_submit()
      assert render(view) =~ "doesn&#39;t match"
      assert {:ok, _} = Plattensammlung.Accounts.get_user(user.id, authorize?: false)

      assert {:error, {:redirect, %{to: "/sign-in"}}} =
               view
               |> form("#delete-account-form", email: " TEST@example.com ")
               |> render_submit()

      assert {:error, _} = Plattensammlung.Accounts.get_user(user.id, authorize?: false)

      # The old session no longer signs in
      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/")
    end

    test "signing out ends the session", %{conn: conn} do
      conn = delete(conn, ~p"/sign-out")
      assert redirected_to(conn) == ~p"/sign-in"

      assert {:error, {:redirect, %{to: "/sign-in"}}} = live(recycle(conn), ~p"/")
    end
  end
end
