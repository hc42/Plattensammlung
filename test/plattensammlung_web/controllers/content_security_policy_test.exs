defmodule PlattensammlungWeb.ContentSecurityPolicyTest do
  use PlattensammlungWeb.ConnCase, async: true

  test "browser pages send a CSP whose nonce the theme script carries", %{conn: conn} do
    conn = get(conn, ~p"/sign-in")

    assert [policy] = get_resp_header(conn, "content-security-policy")
    assert policy =~ "frame-ancestors 'none'"
    assert policy =~ "https://i.discogs.com"

    [_, nonce] = Regex.run(~r/'nonce-([^']+)'/, policy)
    assert html_response(conn, 200) =~ ~s(<script nonce="#{nonce}">)
  end

  test "every response gets a fresh nonce", %{conn: conn} do
    nonce = fn -> conn |> get(~p"/sign-in") |> get_resp_header("content-security-policy") end
    refute nonce.() == nonce.()
  end
end
