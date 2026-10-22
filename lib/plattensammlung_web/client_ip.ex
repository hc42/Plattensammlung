defmodule PlattensammlungWeb.ClientIp do
  @moduledoc """
  The client's IP address (ADR 0017). Behind nginx-proxy-manager every
  connection comes from the proxy, so `X-Forwarded-For` is preferred: its last
  entry, which the proxy itself appended (earlier entries come from the client
  and can be made up). Without the header the address of the connection is used.

  As a plug it sets `conn.remote_ip`; LiveViews call `from_socket/1` in mount
  (the socket's `connect_info` includes `:peer_data` and `:x_headers`).
  """
  @behaviour Plug

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    %{conn | remote_ip: from_headers(conn.req_headers, conn.remote_ip)}
  end

  @doc "The client IP of a LiveView, as a string; nil when not connected."
  def from_socket(socket) do
    with %{address: address} <- Phoenix.LiveView.get_connect_info(socket, :peer_data) do
      headers = Phoenix.LiveView.get_connect_info(socket, :x_headers) || []
      headers |> from_headers(address) |> :inet.ntoa() |> to_string()
    end
  end

  @doc "The last valid address in `X-Forwarded-For`, otherwise `fallback`."
  def from_headers(headers, fallback) do
    headers
    |> Enum.filter(fn {name, _value} -> String.downcase(name) == "x-forwarded-for" end)
    |> Enum.flat_map(fn {_name, value} -> String.split(value, ",") end)
    |> List.last()
    |> parse(fallback)
  end

  defp parse(nil, fallback), do: fallback

  defp parse(value, fallback) do
    case value |> String.trim() |> String.to_charlist() |> :inet.parse_address() do
      {:ok, ip} -> ip
      {:error, _reason} -> fallback
    end
  end
end
