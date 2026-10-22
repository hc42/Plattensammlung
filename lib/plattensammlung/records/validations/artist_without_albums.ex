defmodule Plattensammlung.Records.Validations.ArtistWithoutAlbums do
  @moduledoc """
  An artist can only be deleted once no album refers to it. Albums of other
  users are already ruled out by the policy; this catches the actor's own.
  """
  use Ash.Resource.Validation

  alias Plattensammlung.Records.Album

  require Ash.Query

  @impl true
  def validate(changeset, _opts, _context) do
    id = changeset.data.id

    # The check itself must see all albums, not only those the actor may list
    if Album |> Ash.Query.filter(artist_id == ^id) |> Ash.exists?(authorize?: false) do
      {:error, field: :id, message: "still has albums; delete or move them first"}
    else
      :ok
    end
  end
end
