defmodule Plattensammlung.Records.MergeAlbums do
  @moduledoc """
  Implementation of `Album.merge` (ADR 0024): merges the duplicate `source`
  into `target`, in one transaction:

    * all copies (of every user) move to the target;
    * a wish moves too, unless its owner already has the target in their
      collection or wishlist; wishes on the target of owners who now have a
      copy go (having a copy ends the wish, as when adding one);
    * the target's empty fields are filled from the source (`Album.absorb`),
      the cover only if the target has none;
    * the source is deleted, with its artist if no album is left for them.

  Who may merge is decided by the policy (`Checks.CanMerge`) before this runs;
  the steps here then work across users, so they run without policies.
  The source's cover file is deleted only after the commit, unless it moved.
  """
  use Ash.Resource.Actions.Implementation

  alias Plattensammlung.Covers
  alias Plattensammlung.Records.{Album, Copy, Wish}

  @system [authorize?: false]

  @impl true
  def run(%{arguments: %{source_id: same, target_id: same}}, _opts, _context) do
    {:error,
     Ash.Error.Changes.InvalidArgument.exception(
       field: :source_id,
       message: "is the same album as target_id"
     )}
  end

  def run(%{arguments: %{source_id: source_id, target_id: target_id}}, _opts, context) do
    load = [:copies, :wishes]

    with {:ok, source} <- Ash.get(Album, source_id, [load: load] ++ @system),
         {:ok, target} <- Ash.get(Album, target_id, [load: load] ++ @system),
         {:ok, {target, old_cover}} <-
           Ash.transaction([Album, Copy, Wish], fn -> merge(source, target) end) do
      # The source row is gone for good: now its cover file may go too
      Covers.delete(old_cover)
      Ash.get(Album, target.id, Ash.Context.to_opts(context))
    end
  end

  defp merge(source, target) do
    copy_owners = MapSet.new(target.copies ++ source.copies, & &1.owner_id)
    target_wishers = MapSet.new(target.wishes, & &1.owner_id)

    Enum.each(source.copies, &move!(&1, target))

    for wish <- target.wishes, wish.owner_id in copy_owners, do: Ash.destroy!(wish, @system)

    for wish <- source.wishes do
      if wish.owner_id in copy_owners or wish.owner_id in target_wishers,
        do: Ash.destroy!(wish, @system),
        else: move!(wish, target)
    end

    target =
      target
      |> Ash.Changeset.for_update(:absorb, Map.take(source, Album.absorbed_fields()), @system)
      |> Ash.update!()

    cover_moved? = not is_nil(source.cover_url) and target.cover_url == source.cover_url

    source
    |> Ash.Changeset.for_destroy(:destroy, %{}, @system)
    # The file is deleted after the whole merge, or not at all if it moved
    |> Ash.Changeset.set_context(%{keep_cover: true})
    |> Ash.destroy!()

    {target, if(cover_moved?, do: nil, else: source.cover_url)}
  end

  defp move!(record, target) do
    record
    |> Ash.Changeset.for_update(:move, %{album_id: target.id}, @system)
    |> Ash.update!()
  end
end
