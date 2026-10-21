defmodule Plattensammlung.Records.Changes.NormalizeStreamingIds do
  @moduledoc """
  Accepts pasted Spotify/Tidal links in `spotify_album_id` / `tidal_album_id`
  and keeps only the id.
  """
  use Ash.Resource.Change

  alias Plattensammlung.Records.Streaming

  @impl true
  def change(changeset, _opts, _context) do
    changeset
    |> normalize(:spotify_album_id, &Streaming.spotify_id/1, "is not a Spotify album link")
    |> normalize(:tidal_album_id, &Streaming.tidal_id/1, "is not a Tidal album link")
  end

  defp normalize(changeset, field, parse, message) do
    with true <- Ash.Changeset.changing_attribute?(changeset, field),
         value when is_binary(value) <- Ash.Changeset.get_attribute(changeset, field) do
      case parse.(value) do
        {:ok, id} -> Ash.Changeset.force_change_attribute(changeset, field, id)
        :error -> Ash.Changeset.add_error(changeset, field: field, message: message)
      end
    else
      _ -> changeset
    end
  end
end
