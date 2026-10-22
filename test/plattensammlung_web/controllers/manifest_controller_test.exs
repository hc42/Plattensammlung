defmodule PlattensammlungWeb.ManifestControllerTest do
  use PlattensammlungWeb.ConnCase, async: true

  test "the manifest makes the app installable, without signing in", %{conn: conn} do
    conn = get(conn, ~p"/manifest.webmanifest")

    assert [content_type] = get_resp_header(conn, "content-type")
    assert content_type =~ "application/manifest+json"

    manifest = Jason.decode!(conn.resp_body)
    assert manifest["start_url"] == "/"
    assert manifest["scope"] == "/"
    assert manifest["display"] == "standalone"
    assert Enum.map(manifest["icons"], & &1["sizes"]) == ["192x192", "512x512", "512x512"]
    assert %{"url" => "/import?scan=1"} = hd(manifest["shortcuts"])
  end

  test "the manifest follows the browser language", %{conn: conn} do
    manifest =
      conn
      |> put_req_header("accept-language", "de-DE,de;q=0.9")
      |> get(~p"/manifest.webmanifest")
      |> Map.fetch!(:resp_body)
      |> Jason.decode!()

    assert manifest["lang"] == "de"
    assert %{"name" => "Barcode scannen"} = hd(manifest["shortcuts"])
  end

  test "pages link the manifest; worker, offline page and icons are served", %{conn: conn} do
    assert conn |> get(~p"/sign-in") |> html_response(200) =~
             ~s(<link rel="manifest" href="/manifest.webmanifest">)

    for path <- ~w(/sw.js /offline.html /images/icon-192.png /images/icon-512.png) do
      assert conn |> get(path) |> response(200), path
    end
  end
end
