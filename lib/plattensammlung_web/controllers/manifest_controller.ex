defmodule PlattensammlungWeb.ManifestController do
  @moduledoc """
  The web app manifest (ADR 0022): makes the app installable on the home
  screen. Generated rather than static, so start URL and scope carry the
  optional path prefix (`~p`, ADR 0018) and the texts follow the browser
  language. Public: browsers fetch it without cookies.
  """
  use PlattensammlungWeb, :controller

  # Anthracite of the app icon, also the splash screen background
  @background "#24201d"

  def show(conn, _params) do
    locale =
      conn
      |> get_req_header("accept-language")
      |> List.first()
      |> PlattensammlungWeb.Locale.from_header()

    manifest =
      Gettext.with_locale(PlattensammlungWeb.Gettext, locale, fn ->
        %{
          id: ~p"/",
          name: "Plattensammlung",
          short_name: "Platten",
          description: gettext("Your record collection and wishlist, with barcode scanner."),
          lang: locale,
          start_url: ~p"/",
          scope: ~p"/",
          display: "standalone",
          background_color: @background,
          theme_color: @background,
          icons: [
            %{src: ~p"/images/icon-192.png", sizes: "192x192", type: "image/png"},
            %{src: ~p"/images/icon-512.png", sizes: "512x512", type: "image/png"},
            %{
              src: ~p"/images/icon-512.png",
              sizes: "512x512",
              type: "image/png",
              purpose: "maskable"
            }
          ],
          shortcuts: [
            %{name: gettext("Scan a barcode"), url: ~p"/import?scan=1"},
            %{name: gettext("Wishlist"), url: ~p"/wishlist"}
          ]
        }
      end)

    conn
    |> put_resp_content_type("application/manifest+json")
    |> send_resp(200, Jason.encode!(manifest))
  end
end
