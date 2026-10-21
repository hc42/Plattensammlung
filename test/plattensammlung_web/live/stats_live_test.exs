defmodule PlattensammlungWeb.StatsLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plattensammlung.Records

  describe "signed in" do
    setup :register_and_sign_in_user

    setup do
      Records.add_to_collection!("The Beatles", "Abbey Road", %{genres: ["Rock"]},
        authorize?: false
      )

      :ok
    end

    test "shows key figures and charts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/stats")

      assert view |> element("#kpi-albums") |> render() =~ "1"
      assert has_element?(view, "#chart-genres th", "Rock")
      assert has_element?(view, "#export-csv")
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
