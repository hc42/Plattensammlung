defmodule PlattensammlungWeb.Ownership do
  @moduledoc """
  Edit pages are only for those allowed to change (ADR 0016): the shared album
  data for everyone who has the album in collection or wishlist, a copy only
  for its owner. The Ash policies forbid changes anyway; this sends others back
  to the album page right away instead of showing a form that cannot be saved.
  """
  use PlattensammlungWeb, :verified_routes
  use Gettext, backend: PlattensammlungWeb.Gettext

  require Ash.Query

  @doc """
  The actor's copies of an album, to load as `copies: own_copies(user)`
  (the album's `copies` relationship holds the copies of all users).
  """
  def own_copies(user) do
    Plattensammlung.Records.Copy
    |> Ash.Query.filter(owner_id == ^user.id)
    |> Ash.Query.sort(:inserted_at)
  end

  @doc """
  `:ok` if the actor may change the album (calculation `editable` loaded: they
  have it in collection or wishlist, or nobody has it), else a redirect.
  """
  def require_editable(socket, album) do
    if album.editable do
      :ok
    else
      redirect_back(
        socket,
        album.id,
        gettext("Only those who have the album in their collection or wishlist can change it.")
      )
    end
  end

  @doc "`:ok` for the owner of the copy, else a redirect to its album."
  def require_copy_owner(socket, copy) do
    if copy.owner_id == socket.assigns.current_user.id do
      :ok
    else
      redirect_back(socket, copy.album_id, gettext("Only the owner can change this copy."))
    end
  end

  defp redirect_back(socket, album_id, message) do
    {:redirect,
     socket
     |> Phoenix.LiveView.put_flash(:error, message)
     |> Phoenix.LiveView.redirect(to: ~p"/albums/#{album_id}")}
  end
end
