defmodule Plattensammlung.Records.Changes.RemoveFromWishlist do
  @moduledoc """
  Once a copy of an album is added, the album is owned and no longer wanted.
  """
  use Ash.Resource.Change

  alias Plattensammlung.Records

  @impl true
  def change(changeset, _opts, _context) do
    # after_action runs after the copy is written, in the same transaction
    Ash.Changeset.after_action(changeset, fn _changeset, copy ->
      with {:ok, album} <- Records.get_album(copy.album_id),
           {:ok, _album} <- unmark(album) do
        {:ok, copy}
      end
    end)
  end

  defp unmark(%{wanted: true} = album), do: Records.unmark_wanted(album)
  defp unmark(album), do: {:ok, album}
end
