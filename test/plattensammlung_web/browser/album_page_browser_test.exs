defmodule PlattensammlungWeb.Browser.AlbumPageTest do
  # A real Chromium (ADR 0025): menus, confirmation dialogs, merging
  use PhoenixTest.Playwright.Case, async: true
  use PlattensammlungWeb, :verified_routes

  import PlattensammlungWeb.BrowserHelpers
  import Plattensammlung.AccountsFixtures

  alias Plattensammlung.Records

  setup :stub_lookups

  setup %{conn: conn} do
    user = user_fixture()
    album = Records.add_to_collection!("Harmonia", "Tago Mago", %{year: 1971}, actor: user)

    %{conn: sign_in(conn, user), user: user, album: album}
  end

  test "the ⋯ menu leads to editing", %{conn: conn, album: album} do
    conn
    |> visit(~p"/albums/#{album}")
    |> assert_has("body .phx-connected")
    |> click("#more-actions")
    |> click_link("#edit-album", "Edit")
    |> assert_path(~p"/albums/#{album}/edit")
  end

  test "removing asks first, then takes the album off the collection", %{conn: conn, album: album} do
    conn
    |> visit(~p"/albums/#{album}")
    |> assert_has("body .phx-connected")
    |> click("#more-actions")
    # The data-confirm dialog is accepted (accept_dialogs)
    |> click_button("#remove-album", "Remove")
    |> assert_path(~p"/")
    |> assert_has("#flash-info", text: "“Tago Mago” was removed.")
    |> refute_has("#albums a", text: "Tago Mago")
  end

  test "a duplicate is merged into the album", %{conn: conn, album: album} do
    bob = user_fixture("bob@example.com")

    duplicate =
      Records.create_album!("Harmonia", %{title: "Tago Mago (Remaster)", genres: ["Krautrock"]},
        actor: bob
      )

    Records.add_copy!(duplicate.id, %{}, actor: bob)

    conn
    |> visit(~p"/albums/#{album}")
    |> assert_has("body .phx-connected")
    |> click("#more-actions")
    |> click_link("#merge-album", "Merge duplicate")
    |> assert_has("#candidate-#{duplicate.id}")
    |> click_button("#choose-#{duplicate.id}", "Choose")
    |> assert_has("#keep-#{album.id} input:checked")
    |> click_button("#merge-button", "Merge")
    |> assert_path(~p"/albums/#{album}")
    |> assert_has("#flash-info", text: "Albums merged.")
    |> assert_has("#other-holders", text: "1 copy")
    |> assert_has(".badge", text: "Krautrock")
  end
end
