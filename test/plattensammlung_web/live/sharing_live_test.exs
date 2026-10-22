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

  test "an album nobody has can be edited, matched and removed by anyone",
       %{conn: conn, alice: alice} do
    album = Records.add_to_wishlist!("Can", "Ege Bamyasi", actor: alice)
    Records.unmark_wanted!(album, actor: alice)

    {:ok, view, _html} = live(conn, ~p"/albums/#{album}")
    assert has_element?(view, "#edit-album")
    assert has_element?(view, "#match-album")
    assert has_element?(view, "#remove-album")
    assert has_element?(view, "#change-cover")

    assert {:ok, _view, _html} = live(conn, ~p"/albums/#{album}/edit")
    assert {:ok, match, _html} = live(conn, ~p"/albums/#{album}/match")
    # Let the lookup the page starts finish within the test
    render_async(match)
  end

  test "the collectors page lists the others", %{conn: conn, alice: alice} do
    {:ok, view, _html} = live(conn, ~p"/collectors")

    assert has_element?(view, "#collector-#{alice.id}", "Alice")
    assert has_element?(view, "#collector-#{alice.id} a", "Collection · 1")
  end

  test "someone else's collection is shown read-only", %{conn: conn, alice: alice, album: album} do
    {:ok, view, _html} = live(conn, ~p"/collectors/#{alice.id}")

    assert page_title(view) =~ "Collection of Alice"
    assert has_element?(view, "#albums-#{album.id}")
    refute has_element?(view, "#albums-empty a", "Platte erfassen")
  end

  test "an album only someone else has: who has it, no edits, no foreign copies",
       %{conn: conn, album: album} do
    {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

    assert has_element?(view, "#owned-status", "Not in your collection")
    assert has_element?(view, "#other-holders", "Alice")
    assert has_element?(view, "#other-holders", "1 copy")
    refute has_element?(view, "#edit-album")
    refute has_element?(view, "#remove-album")
    refute has_element?(view, "#cover-form")
    # Alice's copy (with its notes) is hers; the page lists only own copies
    refute has_element?(view, "#copies")
    refute render(view) =~ "Geheim"
  end

  test "an album of someone else can be put on the own wishlist, then edited",
       %{conn: conn, album: album, user: user} do
    {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

    view |> element("#toggle-wanted") |> render_click()

    assert [mine] = Records.search_albums!(nil, :wishlist, actor: user)
    assert mine.id == album.id
    assert has_element?(view, "#owned-status", "On your wishlist")
    # "Auch bei" lists only the others
    assert has_element?(view, "#other-holders", "Alice")
    refute has_element?(view, "#holder-#{user.id}")
    assert has_element?(view, "#edit-album")
    assert {:ok, _view, _html} = live(conn, ~p"/albums/#{album}/edit")
  end

  test "an own copy of someone else's album can be added", %{conn: conn, album: album} do
    assert {:ok, view, _html} = live(conn, ~p"/albums/#{album}/copies/new")

    view |> form("#copy-form") |> render_submit()
    assert_redirect(view, ~p"/albums/#{album}")
  end

  test "edit pages of an album you don't have redirect back", %{conn: conn, album: album} do
    [copy] = Ash.load!(album, :copies, authorize?: false).copies

    for path <- [
          ~p"/albums/#{album}/edit",
          ~p"/albums/#{album}/match",
          ~p"/copies/#{copy}/edit"
        ] do
      assert {:error, {:redirect, %{to: to}}} = live(conn, path)
      assert to == ~p"/albums/#{album}"
    end
  end

  test "removing keeps the album for the others", %{conn: conn, album: album, user: user} do
    Records.mark_wanted!(album, actor: user)
    {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

    view |> element("#remove-album") |> render_click()

    assert_redirect(view, ~p"/wishlist")
    assert {:ok, _} = Records.get_album(album.id, actor: user)
  end

  test "the display name is set on the account page", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/account")

    view |> form("#profile-form", display_name: "  Hans  ") |> render_submit()

    assert Accounts.get_user!(user.id, actor: user).display_name == "Hans"
  end
end
