defmodule PlattensammlungWeb.StatsLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plattensammlung.Records

  describe "signed in" do
    setup :register_and_sign_in_user

    setup %{user: user} do
      Records.add_to_collection!("The Beatles", "Abbey Road", %{genres: ["Rock"]}, actor: user)

      :ok
    end

    test "shows key figures and charts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stats")

      assert view |> element("#kpi-albums") |> render() =~ "1"
      assert has_element?(view, "#chart-genres th", "Rock")
      assert has_element?(view, "#export-csv")
    end

    test "a bar leads to its albums, the filter can be removed", %{conn: conn, user: user} do
      Records.add_to_collection!("Kraftwerk", "Autobahn", %{genres: ["Electronic"]}, actor: user)

      {:ok, view, _html} = live(conn, ~p"/stats")

      view |> element("#chart-genres a", "Rock") |> render_click()
      assert_redirect(view, ~p"/?genre=Rock")

      {:ok, view, _html} = live(conn, ~p"/?genre=Rock")
      assert has_element?(view, "#active-filter-genre", "Rock")
      assert has_element?(view, "#albums a", "Abbey Road")
      refute has_element?(view, "#albums a", "Autobahn")

      view |> element("#active-filter-genre") |> render_click()
      assert_patch(view, ~p"/")
      assert has_element?(view, "#albums a", "Autobahn")
    end

    test "odd URL parameters don't break the album list", %{conn: conn} do
      long = String.duplicate("x", 5000)

      for path <- ["/?q=#{long}", "/?q[]=a", "/?genre=#{long}", "/?decade=99999999999999999999"] do
        assert {:ok, _view, _html} = live(conn, path)
      end
    end

    test "search keeps the filters", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/?decade=1960")

      view |> form("#search-form", %{q: "abbey"}) |> render_change()

      assert_patch(view, ~p"/?decade=1960&q=abbey")
    end

    test "key figure tiles are links", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stats")
      assert has_element?(view, "a#kpi-wishlist[href='/wishlist']")
    end

    test "downloads the CSV export", %{conn: conn} do
      conn = get(conn, ~p"/export/plattensammlung.csv")

      assert response_content_type(conn, :csv) =~ "text/csv"
      assert [disposition] = get_resp_header(conn, "content-disposition")
      assert disposition =~ "attachment"
      assert response(conn, 200) =~ "Abbey Road"
    end

    test "downloads the JSON-LD export", %{conn: conn} do
      conn = get(conn, ~p"/export/plattensammlung.jsonld")

      assert %{"@type" => "ItemList", "numberOfItems" => 1} =
               conn |> response(200) |> Phoenix.json_library().decode!()
    end
  end

  test "exports need a signed-in user", %{conn: conn} do
    assert conn |> get(~p"/export/plattensammlung.csv") |> redirected_to() == ~p"/sign-in"
    assert {:error, {:redirect, %{to: "/sign-in"}}} = live(conn, ~p"/stats")
  end
end
