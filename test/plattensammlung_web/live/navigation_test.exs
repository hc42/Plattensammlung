defmodule PlattensammlungWeb.NavigationTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  setup :register_and_sign_in_user

  test "marks the current page in both navigations", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/wishlist")

    assert has_element?(view, "#nav-wishlist[aria-current=page]")
    assert has_element?(view, "#tab-wishlist[aria-current=page]")
    refute has_element?(view, "#nav-collection[aria-current]")
    refute has_element?(view, "#tab-collection[aria-current]")
  end

  test "collector pages mark the collectors link", %{conn: conn, user: user} do
    {:ok, view, _html} = live(conn, ~p"/collectors/#{user.id}")
    assert has_element?(view, "#nav-collectors[aria-current=page]")
  end

  test "the scan button starts the camera on the import page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert has_element?(view, ~s(#tab-scan[href="/import?scan=1"]))

    {:ok, view, _html} = live(conn, ~p"/import?scan=1")
    assert has_element?(view, ~s(#barcode-scanner[data-autostart="true"]))

    {:ok, view, _html} = live(conn, ~p"/import")
    assert has_element?(view, ~s(#barcode-scanner[data-autostart="false"]))
  end
end
