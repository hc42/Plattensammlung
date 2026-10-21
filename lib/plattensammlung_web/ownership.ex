defmodule PlattensammlungWeb.Ownership do
  @moduledoc """
  Edit pages are only for the owner of an album (ADR 0013). The Ash policies
  forbid changes anyway; this sends others back to the album page right away
  instead of showing a form that cannot be saved.
  """
  use PlattensammlungWeb, :verified_routes

  @doc "Returns `:ok` for the owner, otherwise a socket redirected to the album."
  def require_owner(socket, album) do
    if album.owner_id == socket.assigns.current_user.id do
      :ok
    else
      {:redirect,
       socket
       |> Phoenix.LiveView.put_flash(:error, "Nur der Besitzer kann dieses Album ändern.")
       |> Phoenix.LiveView.redirect(to: ~p"/albums/#{album}")}
    end
  end
end
