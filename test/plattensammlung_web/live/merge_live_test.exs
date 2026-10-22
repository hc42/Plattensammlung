defmodule PlattensammlungWeb.MergeLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plattensammlung.Records

  setup :register_and_sign_in_user

  setup %{user: user} do
    bob = user_fixture("bob@example.com")
    mine = Records.create_album!("Can", %{title: "Tago Mago"}, actor: user)
    Records.add_copy!(mine.id, %{}, actor: user)

    duplicate =
      Records.create_album!("Can", %{title: "Tago Mago (Remaster)", year: 1971}, actor: bob)

    Records.add_copy!(duplicate.id, %{}, actor: bob)

    %{bob: bob, mine: mine, duplicate: duplicate}
  end

  test "finds the duplicate, keeps the chosen album and moves everything over",
       %{conn: conn, mine: mine, duplicate: duplicate, bob: bob} do
    {:ok, view, _html} = live(conn, ~p"/albums/#{mine}")
    assert has_element?(view, ~s(#merge-album[href="/albums/#{mine.id}/merge"]))

    {:ok, view, _html} = live(conn, ~p"/albums/#{mine}/merge")
    # Prefilled with the title, so the remastered entry is found right away
    assert has_element?(view, "#candidate-#{duplicate.id}")
    refute has_element?(view, "#candidate-#{mine.id}")

    view |> element("#choose-#{duplicate.id}") |> render_click()
    assert has_element?(view, "#keep-#{mine.id} input[checked]")

    view |> form("#merge-form", keep: mine.id) |> render_submit()
    assert_redirect(view, ~p"/albums/#{mine}")

    album = Records.get_album!(mine.id, load: [:copies], authorize?: false)
    assert album.year == 1971
    assert bob.id in Enum.map(album.copies, & &1.owner_id)
    assert {:error, _} = Records.get_album(duplicate.id, authorize?: false)
  end

  test "the search finds other entries", %{conn: conn, mine: mine} do
    other =
      Records.create_album!("Kraftwerk", %{title: "Autobahn"}, actor: nil, authorize?: false)

    {:ok, view, _html} = live(conn, ~p"/albums/#{mine}/merge")

    view |> form("#merge-search", q: "autobahn") |> render_change()
    assert has_element?(view, "#candidate-#{other.id}")
  end

  test "albums someone else has can't be merged from their page", %{
    conn: conn,
    duplicate: duplicate
  } do
    assert {:error, {:redirect, %{to: path}}} = live(conn, ~p"/albums/#{duplicate}/merge")
    assert path == ~p"/albums/#{duplicate}"
  end
end
