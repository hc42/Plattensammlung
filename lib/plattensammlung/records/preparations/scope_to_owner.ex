defmodule Plattensammlung.Records.Preparations.ScopeToOwner do
  @moduledoc """
  Limits album lists to one user's albums (ADR 0013): the `owner_id` argument
  if given (looking at someone else's collection), otherwise the actor's own.
  Reading other users' albums is allowed; this only sets the default view.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, _opts, context) do
    case Ash.Query.get_argument(query, :owner_id) || (context.actor && context.actor.id) do
      nil -> query
      owner_id -> Ash.Query.filter(query, owner_id == ^owner_id)
    end
  end
end
