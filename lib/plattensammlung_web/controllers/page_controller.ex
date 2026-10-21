defmodule PlattensammlungWeb.PageController do
  use PlattensammlungWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
