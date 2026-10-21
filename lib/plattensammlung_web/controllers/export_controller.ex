defmodule PlattensammlungWeb.ExportController do
  @moduledoc """
  Downloads of the collection as CSV and JSON-LD (see `Plattensammlung.Records.Export`).
  """
  use PlattensammlungWeb, :controller

  alias Plattensammlung.Records.Export

  plug :require_user

  def csv(conn, _params) do
    send_download(conn, {:binary, Export.csv(actor: conn.assigns.current_user)},
      filename: filename("csv"),
      content_type: "text/csv; charset=utf-8"
    )
  end

  def json_ld(conn, _params) do
    base_url = "#{conn.scheme}://#{conn.host}:#{conn.port}"
    json_ld = Export.json_ld([actor: conn.assigns.current_user], base_url)

    send_download(conn, {:binary, Phoenix.json_library().encode_to_iodata!(json_ld)},
      filename: filename("jsonld"),
      content_type: "application/ld+json"
    )
  end

  defp filename(extension), do: "plattensammlung-#{Date.utc_today()}.#{extension}"

  defp require_user(conn, _opts) do
    if conn.assigns[:current_user] do
      conn
    else
      conn |> redirect(to: ~p"/sign-in") |> halt()
    end
  end
end
