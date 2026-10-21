defmodule Plattensammlung.Records.Preparations.AlbumFilters do
  @moduledoc """
  Optional filters of `Album.search`, used by the statistics drill-down:

    * `genre` – albums with this genre
    * `decade` – `"1970"` for 1970–1979, `"unknown"` for albums without year
    * `artist` – albums of this artist (case-insensitive)
    * `condition` – albums with a copy in this condition (`"very_good_plus"`, …),
      `"none"` for copies without a grade

  A preparation is code that adjusts a read query before it runs; it is used
  here because some filters need parsing that a plain `filter expr(...)` can't do.
  Unknown values are ignored.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  alias Plattensammlung.Records.Condition

  @impl true
  def prepare(query, _opts, _context) do
    query
    |> genre(Ash.Query.get_argument(query, :genre))
    |> decade(Ash.Query.get_argument(query, :decade))
    |> artist(Ash.Query.get_argument(query, :artist))
    |> condition(Ash.Query.get_argument(query, :condition))
  end

  defp genre(query, nil), do: query
  defp genre(query, genre), do: Ash.Query.filter(query, fragment("? = ANY(?)", ^genre, genres))

  defp decade(query, nil), do: query
  defp decade(query, "unknown"), do: Ash.Query.filter(query, is_nil(year))

  defp decade(query, value) do
    case Integer.parse(value) do
      {from, ""} -> Ash.Query.filter(query, year >= ^from and year < ^(from + 10))
      _ -> query
    end
  end

  defp artist(query, nil), do: query
  defp artist(query, name), do: Ash.Query.filter(query, artist.name == ^name)

  defp condition(query, nil), do: query

  defp condition(query, "none"),
    do: Ash.Query.filter(query, exists(copies, is_nil(media_condition)))

  defp condition(query, value) do
    case Condition.match(value) do
      {:ok, grade} -> Ash.Query.filter(query, exists(copies, media_condition == ^grade))
      _ -> query
    end
  end
end
