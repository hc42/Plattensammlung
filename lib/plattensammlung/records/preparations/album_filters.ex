defmodule Plattensammlung.Records.Preparations.AlbumFilters do
  @moduledoc """
  Optional filters of `Album.search`, used by the statistics drill-down:

    * `genre` – albums with this genre
    * `decade` – `"1970"` for 1970–1979, `"unknown"` for albums without year
    * `artist` – albums of this artist (case-insensitive)
    * `condition` – albums with a copy in this condition (`"very_good_plus"`, …),
      `"none"` for copies without a grade; only copies of the listed user
      (`owner_id`, default: the actor)

  A preparation is code that adjusts a read query before it runs; it is used
  here because some filters need parsing that a plain `filter expr(...)` can't do.
  Unknown values are ignored.
  """
  use Ash.Resource.Preparation

  require Ash.Query

  alias Plattensammlung.Records.Condition

  @impl true
  def prepare(query, _opts, context) do
    owner = Ash.Query.get_argument(query, :owner_id) || (context.actor && context.actor.id)

    query
    |> genre(Ash.Query.get_argument(query, :genre))
    |> decade(Ash.Query.get_argument(query, :decade))
    |> artist(Ash.Query.get_argument(query, :artist))
    |> condition(Ash.Query.get_argument(query, :condition), owner)
  end

  defp genre(query, nil), do: query
  defp genre(query, genre), do: Ash.Query.filter(query, fragment("? = ANY(?)", ^genre, genres))

  defp decade(query, nil), do: query
  defp decade(query, "unknown"), do: Ash.Query.filter(query, is_nil(year))

  defp decade(query, value) do
    case Integer.parse(value) do
      # Albums have years 1900–2100; anything else is not a decade of ours
      {from, ""} when from in 1900..2100//10 ->
        Ash.Query.filter(query, year >= ^from and year < ^(from + 10))

      _ ->
        query
    end
  end

  defp artist(query, nil), do: query
  defp artist(query, name), do: Ash.Query.filter(query, artist.name == ^name)

  defp condition(query, nil, _owner), do: query

  defp condition(query, "none", owner),
    do: Ash.Query.filter(query, exists(copies, owner_id == ^owner and is_nil(media_condition)))

  defp condition(query, value, owner) do
    case Condition.match(value) do
      {:ok, grade} ->
        Ash.Query.filter(query, exists(copies, owner_id == ^owner and media_condition == ^grade))

      _ ->
        query
    end
  end
end
