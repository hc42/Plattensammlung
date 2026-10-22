defmodule PlattensammlungWeb.LiveSandbox do
  @moduledoc """
  `on_mount` hook for the browser tests (ADR 0025): lets the LiveView process
  use the test's Ecto sandbox, whose id the browser sends in its user agent.
  Only mounted when `config :plattensammlung, sql_sandbox: true` (test env).
  """
  import Phoenix.LiveView

  def on_mount(:default, _params, _session, socket) do
    if connected?(socket) do
      socket
      |> get_connect_info(:user_agent)
      |> Phoenix.Ecto.SQL.Sandbox.allow(Ecto.Adapters.SQL.Sandbox)
    end

    {:cont, socket}
  end
end
