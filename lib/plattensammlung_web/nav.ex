defmodule PlattensammlungWeb.Nav do
  @moduledoc """
  `on_mount` hook that keeps the current path in `@current_path`, so the
  navigation in `Layouts.app` can mark the active page. The path includes the
  optional prefix (ADR 0018), like the links built with `~p`.
  """
  import Phoenix.Component, only: [assign: 3]
  import Phoenix.LiveView, only: [attach_hook: 4]

  def on_mount(:default, _params, _session, socket) do
    {:cont,
     socket
     |> assign(:current_path, nil)
     |> attach_hook(:current_path, :handle_params, fn _params, url, socket ->
       {:cont, assign(socket, :current_path, URI.parse(url).path)}
     end)}
  end
end
