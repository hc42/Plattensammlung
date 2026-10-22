defmodule Plattensammlung.Records.AddAlbum do
  @moduledoc """
  Implementation of `Album.add_to_collection` and `Album.add_to_wishlist`
  (option `to:`). Albums are shared (ADR 0016), so an album already in the
  catalog is reused, found in this order:

  1. same Discogs master id,
  2. same MusicBrainz release group id,
  3. same artist and title (case-insensitive).

  Then the actor's copy (with the `copy` details) or wish is added. A reused
  album only gets the values it doesn't have yet (`Album.complete`), so no one
  overwrites the shared data by adding an album.

  There is no surrounding transaction (network calls happen before each step's
  own transaction); a new album whose copy fails is deleted again.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Album

  @fields [
    :year,
    :cover_url,
    :genres,
    :discogs_master_id,
    :musicbrainz_release_group_id,
    :spotify_album_id,
    :tidal_album_id
  ]

  @impl true
  def run(input, opts, context) do
    ash_opts = Ash.Context.to_opts(context)
    args = input.arguments
    attrs = args |> Map.take(@fields) |> Map.reject(fn {_key, value} -> value in [nil, []] end)

    with {:ok, album, reused?} <- find_or_create(args, attrs, ash_opts),
         :ok <-
           add_own(opts[:to], album, args, ash_opts) |> undo_on_error(album, reused?, ash_opts),
         {:ok, album} <- complete(reused?, album, attrs, ash_opts) do
      Records.get_album(album.id, [load: [:artist, :owned, :wanted, :copy_count]] ++ ash_opts)
    end
  end

  # Without a transaction (see the action): if the copy is invalid, a just
  # created album must not stay behind as an entry no one has
  defp undo_on_error(:ok, _album, _reused?, _opts), do: :ok

  # Allowed by the destroy policy, as no one has the new album yet
  defp undo_on_error(error, album, false, opts) do
    _ = Records.destroy_album(album, opts)
    error
  end

  defp undo_on_error(error, _album, true, _opts), do: error

  defp find_or_create(args, attrs, opts) do
    case find(args, opts) do
      {:ok, nil} ->
        attrs = Map.put(attrs, :title, args.title)

        with {:ok, album} <- Records.create_album(args.artist_name, attrs, opts) do
          {:ok, album, false}
        end

      {:ok, album} ->
        {:ok, album, true}

      error ->
        error
    end
  end

  defp find(args, opts) do
    Enum.reduce_while(
      [
        args[:discogs_master_id] &&
          Ash.Query.filter(Album, discogs_master_id == ^args.discogs_master_id),
        args[:musicbrainz_release_group_id] &&
          Ash.Query.filter(
            Album,
            musicbrainz_release_group_id == ^args.musicbrainz_release_group_id
          ),
        Ash.Query.for_read(
          Album,
          :duplicates,
          %{artist_name: args.artist_name, title: args.title},
          opts
        )
      ],
      {:ok, nil},
      fn
        nil, acc ->
          {:cont, acc}

        query, acc ->
          case query |> Ash.Query.sort(:id) |> Ash.Query.limit(1) |> Ash.read_one(opts) do
            {:ok, nil} -> {:cont, acc}
            {:ok, album} -> {:halt, {:ok, album}}
            error -> {:halt, error}
          end
      end
    )
  end

  defp add_own(:collection, album, args, opts) do
    with {:ok, _copy} <- Records.add_copy(album.id, args[:copy] || %{}, opts), do: :ok
  end

  defp add_own(:wishlist, album, _args, opts) do
    with {:ok, _wish} <- Records.add_wish(album.id, opts), do: :ok
  end

  defp complete(false, album, _attrs, _opts), do: {:ok, album}
  defp complete(true, album, attrs, _opts) when attrs == %{}, do: {:ok, album}
  defp complete(true, album, attrs, opts), do: Records.complete_album(album, attrs, opts)
end
