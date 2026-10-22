defmodule PlattensammlungWeb.Browser.AppTest do
  # A real Chromium (ADR 0025): service worker, camera start, account deletion
  use PhoenixTest.Playwright.Case, async: true
  use PlattensammlungWeb, :verified_routes

  import PlattensammlungWeb.BrowserHelpers
  import Plattensammlung.AccountsFixtures

  setup :stub_lookups

  setup %{conn: conn} do
    user = user_fixture()
    %{conn: sign_in(conn, user), user: user}
  end

  test "the service worker is installed and keeps the offline page", %{conn: conn} do
    conn
    |> visit(~p"/")
    |> assert_has("body .phx-connected")
    |> evaluate(
      """
      navigator.serviceWorker.ready
        .then(() => caches.open("plattensammlung-offline-v1"))
        .then(cache => cache.match("/offline.html"))
        .then(response => response && response.status)
      """,
      &assert(&1 == 200)
    )
  end

  test "the scan button starts the camera right away", %{conn: conn} do
    # Headless Chromium has no camera: the scanner reports that, which shows it started
    conn
    |> visit(~p"/import?scan=1")
    |> assert_has("body .phx-connected")
    |> assert_has("#barcode-scanner [data-status]:not(:empty)")
  end

  test "deleting the account signs out", %{conn: conn, user: user} do
    conn
    |> visit(~p"/account")
    |> assert_has("body .phx-connected")
    |> fill_in("Your e-mail address to confirm", with: to_string(user.email))
    |> click_button("#delete-account-button", "Delete account")
    |> assert_path(~p"/sign-in")
    |> assert_has("#flash-info", text: "Your account has been deleted.")
    |> visit(~p"/")
    |> assert_path(~p"/sign-in")
  end
end
