defmodule PlattensammlungWeb.SharingLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plattensammlung.{Accounts, Records}

  @moduletag :capture_log

  setup :register_and_sign_in_user

  setup do
    alice = user_fixture("alice@example.com")
    Accounts.update_profile!(alice, "Alice", actor: alice)

    album =
      Records.add_to_collection!(
        "The Beatles",
        "Abbey Road",
        %{
          cover_url: "https://x.test/abbey.jpg",
          copy: %{notes: "Geheim", label: "Apple", purchased_on: ~D[2019-05-03]}
        },
        actor: alice
      )

    %{alice: alice, album: album}
  end

  test "the collectors page lists the others", %{conn: conn, alice: alice} do
    {:ok, view, _html} = live(conn, ~p"/collectors")

    assert has_element?(view, "#collector-#{alice.id}", "Alice")
    assert has_element?(view, "#collector-#{alice.id} a", "Sammlung · 1")
  end

  test "someone else's collection is shown read-only", %{conn: conn, alice: alice, album: album} do
    {:ok, view, _html} = live(conn, ~p"/collectors/#{alice.id}")

    assert page_title(view) =~ "Sammlung von Alice"
    assert has_element?(view, "#albums-#{album.id}")
    refute has_element?(view, "#albums-empty a", "Platte erfassen")
  end

  test "someone else's album has no edit actions and hides private notes",
       %{conn: conn, album: album} do
    {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

    assert has_element?(view, "#owner-info", "Alice")
    refute has_element?(view, "#album-actions")
    refute has_element?(view, "#cover-form")
    refute has_element?(view, "[id^=edit-copy-]")
    assert has_element?(view, "#copies", "Apple")
    refute has_element?(view, "#copies", "Geheim")
    refute has_element?(view, "#copies", "Gekauft am")
  end

  test "an album of someone else can be put on the own wishlist",
       %{conn: conn, album: album, user: user} do
    {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

    view |> element("#add-to-my-wishlist") |> render_click()

    [mine] = Records.search_albums!(nil, :wishlist, actor: user)
    assert_redirect(view, ~p"/albums/#{mine}")
    assert mine.owner_id == user.id
    # Own copy of the cover file, so deleting one album keeps the other's cover
    assert "/covers/" <> _ = mine.cover_url
    refute mine.cover_url == Records.get_album!(album.id, authorize?: false).cover_url

    {:ok, view, _html} = live(conn, ~p"/albums/#{album}")
    assert has_element?(view, "#my-version", "Steht auch auf deiner Wunschliste")
  end

  test "edit pages of someone else's album redirect back", %{conn: conn, album: album} do
    for path <- [
          ~p"/albums/#{album}/edit",
          ~p"/albums/#{album}/match",
          ~p"/albums/#{album}/copies/new"
        ] do
      assert {:error, {:redirect, %{to: to}}} = live(conn, path)
      assert to == ~p"/albums/#{album}"
    end
  end

  test "the display name is set on the account page", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/account")

    view |> form("#profile-form", display_name: "  Hans  ") |> render_submit()

    assert Accounts.get_user!(user.id, actor: user).display_name == "Hans"
  end
end
