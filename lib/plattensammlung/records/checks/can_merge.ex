defmodule Plattensammlung.Records.Checks.CanMerge do
  @moduledoc """
  Policy check for `Album.merge` (ADR 0024): the actor has one of the two
  albums in collection or wishlist, or no one has either of them. Merging the
  same album with itself passes here; the action itself rejects it.
  """
  use Ash.Policy.SimpleCheck

  require Ash.Query

  alias Plattensammlung.Records.Album

  @impl true
  def describe(_opts), do: "actor has one of the two albums, or no one has either"

  @impl true
  def match?(nil, _context, _opts), do: false

  def match?(actor, %{subject: %Ash.ActionInput{arguments: arguments}}, _opts) do
    ids = Enum.uniq([arguments[:source_id], arguments[:target_id]])

    albums =
      Album
      |> Ash.Query.filter(id in ^ids)
      |> Ash.Query.load([:owned, :wanted, :held])
      # Only reads the actor's view of the two albums for this decision
      |> Ash.read!(actor: actor, authorize?: false)

    cond do
      length(ids) == 1 -> true
      length(albums) != 2 -> false
      true -> Enum.any?(albums, &(&1.owned or &1.wanted)) or Enum.all?(albums, &(not &1.held))
    end
  end

  def match?(_actor, _context, _opts), do: false
end
