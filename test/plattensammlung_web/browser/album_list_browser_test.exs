defmodule PlattensammlungWeb.Browser.AlbumListTest do
  # A real Chromium (ADR 0025): the JavaScript of the album list
  use PhoenixTest.Playwright.Case, async: true
  use PlattensammlungWeb, :verified_routes

  import PlattensammlungWeb.BrowserHelpers
  import Plattensammlung.AccountsFixtures

  alias Plattensammlung.Records

  setup :stub_lookups

  setup %{conn: conn} do
    user = user_fixture()
    Records.add_to_collection!("Moebius", "Kind of Blue", %{year: 1959}, actor: user)
    Records.add_to_collection!("Cluster", "Tago Mago", %{year: 1971}, actor: user)

    %{conn: sign_in(conn, user), user: user}
  end

  test "view and order are remembered, back returns to the list as it was", %{conn: conn} do
    conn
    |> visit(~p"/albums?view=list&sort=year")
    |> assert_has("body .phx-connected")
    |> click_link("#albums a", "Kind of Blue")
    |> assert_has("h1", text: "Kind of Blue")
    |> click_link("#back-link", "All albums")
    |> assert_path(~p"/albums", query_params: %{"view" => "list", "sort" => "year"})
    # Another list without parameters opens the same way (sessionStorage → connect params)
    |> visit(~p"/")
    |> assert_has("body .phx-connected")
    |> assert_has("#view-list[aria-pressed=true]")
    # LiveView sets the choice as a property, not as the selected attribute
    |> assert_has("#sort-form select", value: "year")
  end

  test "the background takes the colour of the album under the mouse into its page",
       %{conn: conn, user: user} do
    [tago] = Records.search_albums!("Tago", nil, actor: user)
    # No cover in tests: the album's label colour is the tint
    color = PlattensammlungWeb.AlbumComponents.label_color(tago)

    conn
    |> visit(~p"/albums?view=grid")
    |> assert_has("body .phx-connected")
    |> hover("#albums a:has-text('Tago Mago')")
    |> assert_has("#list-tint[data-tinted]")
    |> evaluate(
      "document.getElementById('list-tint').style.getPropertyValue('--cover-tint')",
      &assert(&1 == color)
    )
    |> click_link("#albums a", "Tago Mago")
    |> assert_has("h1", text: "Tago Mago")
    # The album page starts in that colour instead of fading in from nothing
    |> assert_has("#cover-tint[data-tinted]")
    |> evaluate(
      "document.getElementById('cover-tint').style.getPropertyValue('--cover-tint')",
      &assert(&1 == color)
    )
  end
end
