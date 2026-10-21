defmodule Plattensammlung.Records.Condition do
  @moduledoc """
  Condition of a record or sleeve on the Goldmine grading scale.

  An `Ash.Type.Enum` restricts a value to a fixed set of atoms; it is stored as text.
  """
  use Ash.Type.Enum,
    values: [
      mint: "Mint (M)",
      near_mint: "Near Mint (NM)",
      very_good_plus: "Very Good Plus (VG+)",
      very_good: "Very Good (VG)",
      good_plus: "Good Plus (G+)",
      good: "Good (G)",
      fair: "Fair (F)",
      poor: "Poor (P)"
    ]
end
