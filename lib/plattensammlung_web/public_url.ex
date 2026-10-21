defmodule PlattensammlungWeb.PublicUrl do
  @moduledoc """
  The address users reach the app at, e.g. `https://platten.example.de`.

  In production the app runs behind nginx-proxy-manager and only sees
  `http://nas:4000`, so the address comes from the `:public_url` config
  (`PHX_HOST`, see ADR 0011). In development there is no such config and the
  address of the current request is used (localhost or `<name>.local:4001`).

  Used for WebAuthn origins, magic links and absolute URLs in exports.
  """

  @doc "Base URL without trailing slash for a `Plug.Conn` or a LiveView `socket.host_uri`."
  def base_url(conn_or_uri) do
    Application.get_env(:plattensammlung, :public_url) || request_url(conn_or_uri)
  end

  defp request_url(%Plug.Conn{scheme: scheme, host: host, port: port}),
    do: build(to_string(scheme), host, port)

  defp request_url(%URI{scheme: scheme, host: host, port: port}), do: build(scheme, host, port)

  defp build("http", host, 80), do: "http://#{host}"
  defp build("https", host, 443), do: "https://#{host}"
  defp build(scheme, host, port), do: "#{scheme}://#{host}:#{port}"
end
