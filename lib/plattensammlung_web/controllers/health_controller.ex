defmodule PlattensammlungWeb.HealthController do
  @moduledoc """
  `GET /health` for the container health check: 200 if the database answers.
  """
  use PlattensammlungWeb, :controller

  def show(conn, _params) do
    case Ecto.Adapters.SQL.query(Plattensammlung.Repo, "SELECT 1", []) do
      {:ok, _result} -> send_resp(conn, 200, "ok")
      {:error, _error} -> send_resp(conn, 503, "database unavailable")
    end
  end
end
