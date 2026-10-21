defmodule PlattensammlungWeb.PublicUrlTest do
  # Not async: changes the global public_url config
  use ExUnit.Case, async: false

  alias PlattensammlungWeb.PublicUrl

  test "uses the request address when no public URL is configured" do
    assert PublicUrl.base_url(%URI{scheme: "https", host: "mac.local", port: 4001}) ==
             "https://mac.local:4001"

    assert PublicUrl.base_url(%URI{scheme: "https", host: "example.de", port: 443}) ==
             "https://example.de"
  end

  test "prefers the configured public URL (production behind the proxy)" do
    Application.put_env(:plattensammlung, :public_url, "https://platten.example.de")
    on_exit(fn -> Application.delete_env(:plattensammlung, :public_url) end)

    assert PublicUrl.base_url(%URI{scheme: "http", host: "nas", port: 4000}) ==
             "https://platten.example.de"
  end
end
