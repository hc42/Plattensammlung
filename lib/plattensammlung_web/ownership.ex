defmodule PlattensammlungWeb.Ownership do
  @moduledoc """
  Edit pages are only for those allowed to change (ADR 0016): the shared album
  data for everyone who has the album in collection or wishlist, a copy only
  for its owner. The Ash policies forbid changes anyway; this sends others back
  to the album page right away instead of showing a form that cannot be saved.
  """
  use PlattensammlungWeb, :verified_routes

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

  @doc "`:ok` if the actor has the album (`owned`/`wanted` loaded), else a redirect."
  def require_holder(socket, album) do
    if album.owned or album.wanted do
      :ok
    else
      redirect_back(
        socket,
        album.id,
        "Nur wer das Album in Sammlung oder Wunschliste hat, kann es ändern."
      )
    end
  end

  @doc "`:ok` for the owner of the copy, else a redirect to its album."
  def require_copy_owner(socket, copy) do
    if copy.owner_id == socket.assigns.current_user.id do
      :ok
    else
      redirect_back(socket, copy.album_id, "Nur der Besitzer kann dieses Exemplar ändern.")
    end
  end

  defp redirect_back(socket, album_id, message) do
    {:redirect,
     socket
     |> Phoenix.LiveView.put_flash(:error, message)
     |> Phoenix.LiveView.redirect(to: ~p"/albums/#{album_id}")}
  end
end
