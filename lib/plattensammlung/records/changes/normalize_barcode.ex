defmodule Plattensammlung.Records.Changes.NormalizeBarcode do
  @moduledoc """
  Removes spaces and dashes from a barcode as printed on the sleeve
  ("5 099902 987620" → "5099902987620"). A validation in `Copy` then checks
  for 8 to 14 digits (EAN/UPC).
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    case Ash.Changeset.get_attribute(changeset, :barcode) do
      "" <> barcode ->
        Ash.Changeset.force_change_attribute(
          changeset,
          :barcode,
          String.replace(barcode, ~r/[\s-]/, "")
        )

      _ ->
        changeset
    end
  end
end
