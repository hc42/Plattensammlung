defmodule PlattensammlungWeb.AlbumListTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plattensammlung.Records

  setup :register_and_sign_in_user

  setup %{user: user} do
    Records.add_to_collection!("Miles Davis", "Kind of Blue", %{year: 1959}, actor: user)
    Records.add_to_collection!("Can", "Tago Mago", %{year: 1971}, actor: user)
    Records.add_to_collection!("Can", "Ege Bamyasi", %{year: 1972}, actor: user)
    :ok
  end

  defp titles(view) do
    view
    |> render()
    |> LazyHTML.from_fragment()
    |> LazyHTML.query("#albums a p:first-child")
    |> Enum.map(&LazyHTML.text/1)
  end

  test "the sort menu changes the order and keeps it in the URL", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")
    assert titles(view) == ["Ege Bamyasi", "Kind of Blue", "Tago Mago"]

    view |> form("#sort-form", sort: "year") |> render_change()
    assert_patch(view, ~p"/?sort=year")
    assert titles(view) == ["Kind of Blue", "Tago Mago", "Ege Bamyasi"]
  end

  test "sorted by artist, the A–Z bar jumps to the first album of a letter",
       %{conn: conn, user: user} do
    [tago] = Records.search_albums!("Tago", nil, actor: user)
    {:ok, view, _html} = live(conn, ~p"/?sort=artist")

    assert titles(view) == ["Tago Mago", "Ege Bamyasi", "Kind of Blue"]
    assert has_element?(view, ~s(#letter-bar a[href="#albums-#{tago.id}"]), "C")
    assert has_element?(view, "#letter-bar a", "M")
    refute has_element?(view, "#albums h2")
  end

  test "the list sorted by artist has letter headings", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?sort=artist&view=list")

    assert has_element?(view, "#albums-letter-0", "C")
    assert has_element?(view, "#albums-letter-1", "M")
    assert has_element?(view, ~s(#letter-bar a[href="#albums-letter-0"]), "C")
  end

  test "other orders have no letter bar", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?sort=added")
    refute has_element?(view, "#letter-bar")
    refute has_element?(view, "#albums h2")
  end

  test "the list view is a link away and keeps search and order", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?q=a&sort=year")

    view |> element("#view-list") |> render_click()
    assert_patch(view, ~p"/?q=a&sort=year&view=list")
    assert has_element?(view, "#view-list[aria-pressed=true]")
    assert titles(view) == ["Kind of Blue", "Tago Mago", "Ege Bamyasi"]
  end

  test "unknown sort and view values are ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/?sort=evil&view=table")
    assert titles(view) == ["Ege Bamyasi", "Kind of Blue", "Tago Mago"]
    assert has_element?(view, "#view-grid[aria-pressed=true]")
  end
end
