defmodule Plattensammlung.Records.Changes.StoreCover do
  @moduledoc """
  When an album gets a remote cover URL, the image is downloaded and the
  album points to the local copy instead. A replaced local cover is deleted.
  If the download fails, the remote URL is kept.
  """
  use Ash.Resource.Change

  alias Plattensammlung.Covers

  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    if Ash.Changeset.changing_attribute?(changeset, :cover_url) do
      previous = changeset.data.cover_url

      changeset
      # Runs before the database transaction opens, so a slow download
      # does not hold a transaction
      |> Ash.Changeset.before_transaction(&download/1)
      |> Ash.Changeset.after_transaction(fn
        _changeset, {:ok, album} = result ->
          if album.cover_url != previous, do: Covers.delete(previous)
          result

        _changeset, error ->
          error
      end)
    else
      changeset
    end
  end

  defp download(changeset) do
    url = Ash.Changeset.get_attribute(changeset, :cover_url)

    if Covers.remote?(url) do
      case Covers.store(url) do
        {:ok, local_url} ->
          Ash.Changeset.force_change_attribute(changeset, :cover_url, local_url)

        {:error, reason} ->
          Logger.warning("Could not store cover #{url}: #{inspect(reason)}")
          changeset
      end
    else
      changeset
    end
  end
end
