defmodule Plattensammlung.Records.RemoveAlbum do
  @moduledoc """
  Implementation of `Album.remove`: deletes the actor's copies of the album and
  their wish. Other users' copies and wishes stay. Once no one has the album
  any more, it is deleted as well (with its cover and, if unused, its artist).
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Plattensammlung.Records
  alias Plattensammlung.Records.{Copy, Wishlist}

  @impl true
  def run(input, _opts, context) do
    opts = Ash.Context.to_opts(context)
    album_id = input.arguments.album_id
    actor_id = context.actor && context.actor.id

    with {:ok, album} <- Records.get_album(album_id, opts),
         :ok <- destroy_own_copies(album_id, actor_id, opts),
         :ok <- Wishlist.remove(album_id, opts) do
      delete_if_unused(album, opts)
    end
  end

  defp destroy_own_copies(album_id, actor_id, opts) do
    Copy
    |> Ash.Query.filter(album_id == ^album_id and owner_id == ^actor_id)
    |> Ash.bulk_destroy(
      :destroy,
      %{},
      [strategy: :stream, allow_stream_with: :full_read, return_errors?: true] ++ opts
    )
    |> case do
      %Ash.BulkResult{status: :success} -> :ok
      %Ash.BulkResult{errors: [error | _]} -> {:error, error}
    end
  end

  # The destroy policy only allows albums no one has: otherwise it stays
  defp delete_if_unused(album, opts) do
    case Records.destroy_album(album, opts) do
      :ok -> :ok
      {:ok, _album} -> :ok
      {:error, %Ash.Error.Forbidden{}} -> :ok
      error -> error
    end
  end
end
