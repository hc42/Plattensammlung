defmodule Plattensammlung.Records.Changes.KeepExistingValues do
  @moduledoc """
  Drops changes to fields that already have a value, so `Album.complete` only
  fills gaps in the shared album data. A cover that is still a remote URL (its
  download failed) counts as empty.
  """
  use Ash.Resource.Change

  alias Plattensammlung.Covers

  @impl true
  def change(changeset, _opts, _context) do
    Enum.reduce(Map.keys(changeset.attributes), changeset, fn field, changeset ->
      if empty?(field, Map.get(changeset.data, field)),
        do: changeset,
        else: Ash.Changeset.clear_change(changeset, field)
    end)
  end

  defp empty?(:cover_url, url), do: is_nil(url) or Covers.remote?(url)
  defp empty?(_field, value), do: value in [nil, []]
end
