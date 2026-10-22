defmodule PlattensammlungWeb.MetricsTest do
  @moduledoc "Prometheus metrics (ADR 0019)."
  # Not async: the metrics are global counters
  use PlattensammlungWeb.ConnCase, async: false

  alias Plattensammlung.{Metrics, Records}
  alias PlattensammlungWeb.MetricsPlug

  defp scrape do
    conn = Plug.Test.conn(:get, "/metrics") |> MetricsPlug.call([])
    assert conn.status == 200
    assert ["text/plain" <> _] = Plug.Conn.get_resp_header(conn, "content-type")
    conn.resp_body
  end

  test "HTTP requests are counted by route pattern, not by path", %{conn: conn} do
    get(conn, ~p"/sign-in")

    body = scrape()
    assert body =~ ~r/plattensammlung_http_requests_count\{[^}]*route="\/sign-in"/
    assert body =~ ~s(client="anonymous")
    assert body =~ "plattensammlung_http_request_duration_milliseconds_bucket"
  end

  test "sign-ins and magic link requests are counted" do
    Metrics.sign_in(:passkey, :failure)
    Plattensammlung.Accounts.request_magic_link("stranger@example.com")

    body = scrape()

    assert body =~
             ~r/plattensammlung_auth_sign_ins_count\{[^}]*method="passkey"[^}]*result="failure"|plattensammlung_auth_sign_ins_count\{[^}]*result="failure"[^}]*method="passkey"/

    assert body =~ ~r/plattensammlung_auth_magic_link_requests_count\{result="accepted"\}/
  end

  test "Ash actions and data volumes are reported" do
    user = user_fixture()
    Records.add_to_collection!("Can", "Tago Mago", actor: user)
    Metrics.measure_data()

    body = scrape()
    assert body =~ ~r/plattensammlung_ash_actions_count\{[^}]*resource="album"/
    assert body =~ ~r/plattensammlung_data_albums \d+/
    assert body =~ ~r/plattensammlung_data_copies \d+/
  end

  test "other paths are not served" do
    assert Plug.Test.conn(:get, "/") |> MetricsPlug.call([]) |> Map.fetch!(:status) == 404
  end
end
