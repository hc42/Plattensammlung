defmodule Plattensammlung.Records.Changes.FillStreamingLinks do
  @moduledoc """
  Fills missing Spotify/Tidal ids (and a missing MusicBrainz link found on the
  way) via `Plattensammlung.Lookup.StreamingLinks`, using the album's Discogs or
  MusicBrainz link. Runs before the transaction (network calls) and never fails
  the action: without an answer the fields simply stay empty.

  Option `when: :always` (default) or `when: :links_changed` (only if the
  MusicBrainz/Discogs id is being changed, so plain edits stay offline).
  """
  use Ash.Resource.Change

  alias Plattensammlung.Lookup.StreamingLinks

  @impl true
  def change(changeset, opts, _context) do
    if run?(changeset, Keyword.get(opts, :when, :always)) do
      Ash.Changeset.before_transaction(changeset, &fill/1)
    else
      changeset
    end
  end

  defp run?(_changeset, :always), do: true

  defp run?(changeset, :links_changed) do
    Ash.Changeset.changing_attribute?(changeset, :musicbrainz_release_group_id) or
      Ash.Changeset.changing_attribute?(changeset, :discogs_master_id)
  end

  defp fill(changeset) do
    current = %{
      spotify: Ash.Changeset.get_attribute(changeset, :spotify_album_id),
      tidal: Ash.Changeset.get_attribute(changeset, :tidal_album_id),
      musicbrainz: Ash.Changeset.get_attribute(changeset, :musicbrainz_release_group_id),
      discogs: Ash.Changeset.get_attribute(changeset, :discogs_master_id)
    }

    if (is_nil(current.spotify) or is_nil(current.tidal)) and
         (current.musicbrainz || current.discogs) do
      found = StreamingLinks.find(current)

      changeset
      |> maybe_set(:spotify_album_id, current.spotify, found.spotify)
      |> maybe_set(:tidal_album_id, current.tidal, found.tidal)
      |> maybe_set(:musicbrainz_release_group_id, current.musicbrainz, found.musicbrainz)
    else
      changeset
    end
  end

  defp maybe_set(changeset, field, nil, new) when is_binary(new),
    do: Ash.Changeset.force_change_attribute(changeset, field, new)

  defp maybe_set(changeset, _field, _current, _new), do: changeset
end
