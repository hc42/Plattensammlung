defmodule Plattensammlung.Records.Changes.FindOrCreateArtist do
  @moduledoc """
  Relates an album to the artist named in the `artist_name` argument, creating
  the artist if it does not exist yet. Lookup is case-insensitive, so
  "the beatles" reuses an existing "The Beatles".
  """
  use Ash.Resource.Change

  alias Plattensammlung.Records

  @impl true
  def change(changeset, _opts, context) do
    case Ash.Changeset.get_argument(changeset, :artist_name) do
      nil ->
        changeset

      name ->
        # before_action runs inside the action's transaction, right before the write
        Ash.Changeset.before_action(changeset, fn changeset ->
          case find_or_create(name, Ash.Context.to_opts(context)) do
            {:ok, artist} ->
              Ash.Changeset.force_change_attribute(changeset, :artist_id, artist.id)

            {:error, error} ->
              Ash.Changeset.add_error(changeset, error)
          end
        end)
    end
  end

  # Same actor and authorization as the album action
  defp find_or_create(name, opts) do
    case Records.get_artist_by_name(name, [not_found_error?: false] ++ opts) do
      {:ok, nil} -> Records.create_artist(name, opts)
      result -> result
    end
  end
end
