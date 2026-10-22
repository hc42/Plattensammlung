defmodule Plattensammlung.Records.Changes.StoreUploadedCover do
  @moduledoc """
  Stores the uploaded image from the `image` argument (`Ash.Type.File`) as the
  album cover and deletes the previous local cover afterwards.
  """
  use Ash.Resource.Change

  alias Plattensammlung.Covers

  @impl true
  def change(changeset, _opts, _context) do
    previous = changeset.data.cover_url

    changeset
    |> Ash.Changeset.before_transaction(fn changeset ->
      with %Ash.Type.File{} = file <- Ash.Changeset.get_argument(changeset, :image),
           {:ok, path} <- Ash.Type.File.path(file),
           {:ok, cover_url} <- Covers.store_file(path) do
        changeset
        |> Ash.Changeset.force_change_attribute(:cover_url, cover_url)
        |> Ash.Changeset.put_context(:stored_cover, cover_url)
      else
        _error ->
          Ash.Changeset.add_error(changeset,
            field: :image,
            message: "must be a JPEG, PNG, WebP or GIF image up to 10 MB"
          )
      end
    end)
    |> Ash.Changeset.after_transaction(fn
      _changeset, {:ok, album} = result ->
        if album.cover_url != previous, do: Covers.delete(previous)
        result

      changeset, error ->
        # Saving failed: remove the file stored before the transaction
        Covers.delete(changeset.context[:stored_cover])
        error
    end)
  end
end
