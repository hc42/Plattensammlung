defmodule Plattensammlung.Records.Changes.RemoveFromWishlist do
  @moduledoc """
  Once the actor adds a copy of an album, it is no longer on their wishlist
  (their wish is deleted; other users' wishes stay).
  """
  use Ash.Resource.Change

  alias Plattensammlung.Records.Wishlist

  @impl true
  def change(changeset, _opts, context) do
    # after_action runs after the copy is written, in the same transaction;
    # same actor and authorization as the copy action
    Ash.Changeset.after_action(changeset, fn _changeset, copy ->
      with :ok <- Wishlist.remove(copy.album_id, Ash.Context.to_opts(context)) do
        {:ok, copy}
      end
    end)
  end
end
