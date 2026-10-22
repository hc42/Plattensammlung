defmodule Plattensammlung.Records.Validations.CoverSource do
  @moduledoc """
  A cover URL given as input must be an https URL from a known cover host
  (`Plattensammlung.Covers.allowed_url?/1`), or empty. Local `/covers/…` paths
  are only set by the app itself (download, upload): otherwise anyone could
  point an album at another album's cover file and delete it along with the
  album (ADR 0014).
  """
  use Ash.Resource.Validation

  alias Plattensammlung.Covers

  @impl true
  def validate(changeset, _opts, _context) do
    with true <- Ash.Changeset.changing_attribute?(changeset, :cover_url),
         url when url not in [nil, ""] <- Ash.Changeset.get_attribute(changeset, :cover_url),
         false <- Covers.allowed_url?(url) do
      {:error,
       field: :cover_url,
       message: "must be an https URL from Discogs or the Cover Art Archive (or use the upload)"}
    else
      _ -> :ok
    end
  end
end
