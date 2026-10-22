defmodule PlattensammlungWeb.Plugs.ContentSecurityPolicy do
  @moduledoc """
  Content-Security-Policy for the browser pages (ADR 0014): a second line of
  defence should anything slip past HEEx escaping.

  * Scripts only from the app itself; the inline theme script in the root
    layout carries the per-request nonce from `@csp_nonce`.
  * Images from the app, `data:`/`blob:` (upload previews) and the cover hosts
    (`Plattensammlung.Covers.hosts/0`, e.g. lookup thumbnails).
  * Inline `style` attributes are allowed (cover background, LiveView
    transitions), `<style>` elements are not.
  * No framing, no plugins, forms only to the app.
  """
  @behaviour Plug

  import Plug.Conn

  @impl true
  def init(opts), do: opts

  @impl true
  def call(conn, _opts) do
    nonce = 18 |> :crypto.strong_rand_bytes() |> Base.encode64()

    conn
    |> assign(:csp_nonce, nonce)
    |> put_resp_header("content-security-policy", policy(nonce))
  end

  defp policy(nonce) do
    cover_hosts =
      Enum.flat_map(Plattensammlung.Covers.hosts(), &["https://#{&1}", "https://*.#{&1}"])

    Enum.map_join(
      [
        ["default-src", "'self'"],
        ["script-src", "'self'", "'nonce-#{nonce}'"],
        ["style-src", "'self'"],
        ["style-src-attr", "'unsafe-inline'"],
        ["img-src", "'self'", "data:", "blob:" | cover_hosts],
        ["connect-src", "'self'"],
        ["object-src", "'none'"],
        ["base-uri", "'self'"],
        ["form-action", "'self'"],
        ["frame-ancestors", "'none'"]
      ],
      "; ",
      &Enum.join(&1, " ")
    )
  end
end
