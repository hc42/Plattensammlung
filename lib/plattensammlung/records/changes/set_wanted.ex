defmodule Plattensammlung.Records.Changes.SetWanted do
  @moduledoc """
  Puts the album on the actor's wishlist or takes it off (their `Wish`), from
  the option `wanted:` or the action argument `wanted` (nil = unchanged).
  Other users' wishes are not touched (ADR 0016).
  """
  use Ash.Resource.Change

  alias Plattensammlung.Records
  alias Plattensammlung.Records.Wishlist

  @impl true
  def change(changeset, opts, context) do
    wanted =
      case Keyword.fetch(opts, :wanted) do
        {:ok, wanted} -> wanted
        :error -> Ash.Changeset.get_argument(changeset, :wanted)
      end

    if is_nil(wanted) do
      changeset
    else
      Ash.Changeset.after_action(changeset, fn _changeset, album ->
        with :ok <- set(wanted, album.id, Ash.Context.to_opts(context)), do: {:ok, album}
      end)
    end
  end

  defp set(true, album_id, opts) do
    with {:ok, _wish} <- Records.add_wish(album_id, opts), do: :ok
  end

  defp set(false, album_id, opts), do: Wishlist.remove(album_id, opts)
end
