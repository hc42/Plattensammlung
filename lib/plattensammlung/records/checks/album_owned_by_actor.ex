defmodule Plattensammlung.Records.Checks.AlbumOwnedByActor do
  @moduledoc """
  Policy check for creating copies: the album the copy is added to must belong
  to the actor (ADR 0013). A plain filter can't express this for creates,
  because the copy doesn't exist yet.
  """
  use Ash.Policy.SimpleCheck

  alias Plattensammlung.Records.Album

  @impl true
  def describe(_opts), do: "the album of the copy belongs to the actor"

  @impl true
  def match?(%{id: actor_id}, %{changeset: %Ash.Changeset{} = changeset}, _opts) do
    case Ash.Changeset.get_attribute(changeset, :album_id) do
      nil ->
        false

      album_id ->
        # Only the owner id is needed; reading it must not depend on the actor
        match?({:ok, %{owner_id: ^actor_id}}, Ash.get(Album, album_id, authorize?: false))
    end
  end

  def match?(_actor, _context, _opts), do: false
end
