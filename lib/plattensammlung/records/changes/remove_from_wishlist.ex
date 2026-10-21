defmodule Plattensammlung.Records.Changes.RemoveFromWishlist do
  @moduledoc """
  Once a copy of an album is added, the album is owned and no longer wanted.
  """
  use Ash.Resource.Change

  alias Plattensammlung.Records

  @impl true
  def change(changeset, _opts, context) do
    # after_action runs after the copy is written, in the same transaction
    # Same actor and authorization as the copy action
    opts = Ash.Context.to_opts(context)

    Ash.Changeset.after_action(changeset, fn _changeset, copy ->
      with {:ok, album} <- Records.get_album(copy.album_id, opts),
           {:ok, _album} <- unmark(album, opts) do
        {:ok, copy}
      end
    end)
  end

  defp unmark(%{wanted: true} = album, opts), do: Records.unmark_wanted(album, opts)
  defp unmark(album, _opts), do: {:ok, album}
end
