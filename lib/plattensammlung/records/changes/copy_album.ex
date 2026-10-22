defmodule Plattensammlung.Records.Changes.CopyAlbum do
  @moduledoc """
  Fills a new album with the data of the album in the `album_id` argument
  (usually someone else's): artist, title, year, genres and links, but not the
  copies. A local cover file is duplicated before the transaction, so the two
  albums never share a file; if saving fails, the duplicate is removed again.
  """
  use Ash.Resource.Change

  alias Plattensammlung.{Covers, Records}

  @fields [
    :title,
    :year,
    :genres,
    :discogs_master_id,
    :musicbrainz_release_group_id,
    :spotify_album_id,
    :tidal_album_id
  ]

  @impl true
  def change(changeset, _opts, context) do
    album_id = Ash.Changeset.get_argument(changeset, :album_id)

    case Records.get_album(album_id, [load: [:artist]] ++ Ash.Context.to_opts(context)) do
      {:ok, source} ->
        changeset
        |> Ash.Changeset.force_change_attributes(Map.take(source, @fields))
        |> Ash.Changeset.set_argument(:artist_name, source.artist.name)
        |> Ash.Changeset.before_transaction(&copy_cover(&1, source.cover_url))
        |> Ash.Changeset.after_transaction(fn
          _changeset, {:ok, _album} = result ->
            result

          changeset, error ->
            Covers.delete(changeset.context[:stored_cover])
            error
        end)

      {:error, error} ->
        Ash.Changeset.add_error(changeset, error)
    end
  end

  # Remote URLs pass the cover-source rules already (they were validated on input)
  defp copy_cover(changeset, url) do
    copy = Covers.duplicate(url)

    changeset
    |> Ash.Changeset.force_change_attribute(:cover_url, copy)
    |> Ash.Changeset.put_context(:stored_cover, copy)
  end
end
