defmodule PlattensammlungWeb.HealthControllerTest do
  use PlattensammlungWeb.ConnCase, async: true

  test "GET /health answers without sign-in", %{conn: conn} do
    assert conn |> get(~p"/health") |> response(200) == "ok"
  end
end
