defmodule Plattensammlung.Records.Preparations.ScopeToOwner do
  @moduledoc """
  Limits album lists to one user's collection or wishlist (ADR 0016): the
  `owner_id` argument if given (looking at someone else's lists), otherwise the
  actor's own. The status comes from the option `status:` or the `status`
  argument; without one the whole shared catalog is listed.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  @impl true
  def prepare(query, opts, context) do
    status = opts[:status] || Ash.Query.get_argument(query, :status)
    owner = Ash.Query.get_argument(query, :owner_id) || (context.actor && context.actor.id)

    case {status, owner} do
      {nil, _owner} ->
        query

      {_status, nil} ->
        Ash.Query.filter(query, false)

      {:collection, owner} ->
        Ash.Query.filter(query, exists(copies, owner_id == ^owner))

      {:wishlist, owner} ->
        Ash.Query.filter(query, exists(wishes, owner_id == ^owner))

      {:other, owner} ->
        Ash.Query.filter(
          query,
          not exists(copies, owner_id == ^owner) and not exists(wishes, owner_id == ^owner)
        )
    end
  end
end
