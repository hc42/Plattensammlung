defmodule PlattensammlungWeb.ClientIpTest do
  use ExUnit.Case, async: true

  alias PlattensammlungWeb.ClientIp

  @fallback {10, 0, 0, 2}

  test "prefers the last X-Forwarded-For entry, the one the proxy added" do
    headers = [{"x-forwarded-for", "1.2.3.4, 203.0.113.7"}]
    assert ClientIp.from_headers(headers, @fallback) == {203, 0, 113, 7}
  end

  test "IPv6 works too" do
    assert ClientIp.from_headers([{"x-forwarded-for", "2001:db8::1"}], @fallback) ==
             {8193, 3512, 0, 0, 0, 0, 0, 1}
  end

  test "falls back to the connection's address without or with a broken header" do
    assert ClientIp.from_headers([], @fallback) == @fallback
    assert ClientIp.from_headers([{"x-forwarded-for", "nonsense"}], @fallback) == @fallback
  end

  test "the plug sets remote_ip" do
    conn =
      Plug.Test.conn(:get, "/")
      |> Plug.Conn.put_req_header("x-forwarded-for", "203.0.113.7")
      |> ClientIp.call([])

    assert conn.remote_ip == {203, 0, 113, 7}
  end
end
