defmodule Plattensammlung.Records.Changes.ApplyMatch do
  @moduledoc """
  Copies album data from the `result` argument (a `LookupResult`) according to
  the `mode` argument; `Plattensammlung.Records.AlbumMatch` decides which fields.
  Runs before `StoreCover`, which then downloads a new cover.

  Pressing details of a barcode result go to the copy given as `copy_id`, or
  into a new copy with `new_copy: true`, in the same transaction.
  """
  use Ash.Resource.Change

  alias Plattensammlung.{Lookup, Records}
  alias Plattensammlung.Records.AlbumMatch

  @impl true
  def change(changeset, _opts, context) do
    result = Ash.Changeset.get_argument(changeset, :result)
    mode = Ash.Changeset.get_argument(changeset, :mode)
    opts = Ash.Context.to_opts(context)

    changeset
    |> Ash.Changeset.force_change_attributes(AlbumMatch.changes(changeset.data, result, mode))
    |> Ash.Changeset.after_action(fn changeset, album ->
      with :ok <- apply_pressing(changeset, album, result, mode, opts) do
        {:ok, album}
      end
    end)
  end

  defp apply_pressing(changeset, album, result, mode, opts) do
    copy_id = Ash.Changeset.get_argument(changeset, :copy_id)
    new_copy? = Ash.Changeset.get_argument(changeset, :new_copy)

    cond do
      not AlbumMatch.pressing?(result) ->
        :ok

      new_copy? ->
        with {:ok, _copy} <- Records.add_copy(album.id, Lookup.copy_attrs(result), opts), do: :ok

      copy_id ->
        with {:ok, copy} <- Records.get_copy(copy_id, opts),
             :ok <- same_album(copy, album) do
          update_copy(copy, AlbumMatch.copy_changes(copy, result, mode), opts)
        end

      true ->
        :ok
    end
  end

  defp same_album(%{album_id: id}, %{id: id}), do: :ok

  defp same_album(_copy, _album),
    do:
      {:error,
       Ash.Error.Changes.InvalidArgument.exception(
         field: :copy_id,
         message: "belongs to another album"
       )}

  defp update_copy(_copy, changes, _opts) when changes == %{}, do: :ok

  defp update_copy(copy, changes, opts) do
    with {:ok, _copy} <- Records.update_copy(copy, changes, opts), do: :ok
  end
end
