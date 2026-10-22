defmodule Plattensammlung.Records.Wishlist do
  @moduledoc """
  Helpers around the actor's `Wish` records (ADR 0016).
  """
  alias Plattensammlung.Records.Wish

  @doc "Deletes the actor's wish for `album_id`, if there is one."
  def remove(album_id, opts) do
    Wish
    |> Ash.Query.for_read(:mine, %{album_id: album_id}, opts)
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
end
