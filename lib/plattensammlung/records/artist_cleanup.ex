defmodule Plattensammlung.Records.ArtistCleanup do
  @moduledoc """
  Removes artists that no album refers to any more (ADR 0015): after an album
  is deleted or moved to another artist, and once after app start for leftovers.
  Failures are only logged, as the album action itself has succeeded.
  """
  alias Plattensammlung.Records.Artist

  require Ash.Query
  require Logger

  @doc "Deletes the artist with `id` if it has no albums left."
  def remove_if_orphaned(nil, _opts), do: :ok

  def remove_if_orphaned(id, opts) do
    Artist
    |> Ash.Query.for_read(:orphans, %{}, opts)
    |> Ash.Query.filter(id == ^id)
    |> destroy(opts)
  end

  @doc "Deletes all artists without albums (system task, no actor)."
  def cleanup_orphans do
    Artist
    |> Ash.Query.for_read(:orphans, %{}, authorize?: false)
    |> destroy(authorize?: false)
  end

  defp destroy(query, opts) do
    case Ash.bulk_destroy(
           query,
           :destroy,
           %{},
           [strategy: :stream, allow_stream_with: :full_read, return_errors?: true] ++ opts
         ) do
      %Ash.BulkResult{status: :success} ->
        :ok

      %Ash.BulkResult{errors: errors} ->
        Logger.warning("Could not remove orphaned artists: #{inspect(errors)}")
        :ok
    end
  end
end
