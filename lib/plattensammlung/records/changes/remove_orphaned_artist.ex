defmodule Plattensammlung.Records.Changes.RemoveOrphanedArtist do
  @moduledoc """
  After an album is deleted or gets another artist, the previous artist is
  removed if no album (of any user) refers to it any more.
  """
  use Ash.Resource.Change

  alias Plattensammlung.Records.ArtistCleanup

  @impl true
  def change(changeset, _opts, context) do
    previous = changeset.data.artist_id

    Ash.Changeset.after_transaction(changeset, fn
      _changeset, {:ok, album} = result ->
        if changeset.action_type == :destroy or album.artist_id != previous do
          ArtistCleanup.remove_if_orphaned(previous, Ash.Context.to_opts(context))
        end

        result

      _changeset, error ->
        error
    end)
  end
end
