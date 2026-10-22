defmodule Plattensammlung.Records.Statistics do
  @moduledoc """
  Implementation of the generic action `Album.statistics`: key figures and
  breakdowns of the collection.

  Totals are computed by the database with `Ash.count/2`
  (aggregate queries). Breakdowns (genres, decades, …) are counted in Elixir,
  which is plenty fast for a private collection and keeps genre lists simple.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Plattensammlung.Records.{Album, Artist, Condition, Copy}

  @top 8

  @impl true
  def run(input, _opts, context) do
    # Same actor and authorization as the calling action
    opts = Ash.Context.to_opts(context)
    # Someone else's collection if asked for, otherwise the actor's own (ADR 0016)
    owner = input.arguments[:owner_id] || (context.actor && context.actor.id)

    owned = Ash.Query.filter(Album, exists(copies, owner_id == ^owner))
    copies = Ash.Query.filter(Copy, owner_id == ^owner)

    with {:ok, albums} <- Ash.count(owned, opts),
         {:ok, copy_count} <- Ash.count(copies, opts),
         {:ok, wishlist} <-
           Ash.count(Ash.Query.filter(Album, exists(wishes, owner_id == ^owner)), opts),
         {:ok, artists} <-
           Ash.count(
             Ash.Query.filter(Artist, exists(albums, exists(copies, owner_id == ^owner))),
             opts
           ),
         {:ok, collection} <- Ash.read(Ash.Query.load(owned, :artist), opts),
         {:ok, all_copies} <- Ash.read(copies, opts) do
      {:ok,
       %{
         albums: albums,
         copies: copy_count,
         wishlist: wishlist,
         artists: artists,
         genres: genres(collection),
         decades: decades(collection),
         conditions: conditions(all_copies),
         top_artists: top_artists(collection)
       }}
    end
  end

  # Each breakdown is a list of %{label, count, filter}, ready for bars and for
  # JSON. `filter` holds the Album.search arguments that list exactly these albums
  # (nil for the folded "Other" entry). Labels are English (also in the API);
  # the web interface translates them by their filter.

  defp genres(albums) do
    albums
    |> Enum.flat_map(& &1.genres)
    |> Enum.frequencies()
    |> top_with_rest(&%{"genre" => &1})
  end

  defp decades(albums) do
    albums
    |> Enum.map(fn
      %{year: nil} -> :unknown
      %{year: year} -> div(year, 10) * 10
    end)
    |> Enum.frequencies()
    # Chronological, unknown last (atoms sort after integers)
    |> Enum.sort()
    |> Enum.map(fn
      {:unknown, count} -> entry("Unknown", count, %{"decade" => "unknown"})
      {decade, count} -> entry("#{decade}s", count, %{"decade" => to_string(decade)})
    end)
  end

  defp conditions(copies) do
    counts = copies |> Enum.map(& &1.media_condition) |> Enum.frequencies()

    # Goldmine order from best to worst, only grades that occur
    (Condition.values() ++ [nil])
    |> Enum.filter(&Map.has_key?(counts, &1))
    |> Enum.map(&entry(condition_label(&1), counts[&1], %{"condition" => condition_key(&1)}))
  end

  defp top_artists(albums) do
    albums
    |> Enum.map(&to_string(&1.artist.name))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {name, count} -> {-count, name} end)
    |> Enum.take(@top)
    |> Enum.map(fn {name, count} -> entry(name, count, %{"artist" => name}) end)
  end

  # Largest first; everything after the top entries is folded into "Other"
  defp top_with_rest(frequencies, filter) do
    {top, rest} =
      frequencies
      |> Enum.sort_by(fn {label, count} -> {-count, label} end)
      |> Enum.split(@top)

    rest_count = rest |> Enum.map(&elem(&1, 1)) |> Enum.sum()

    Enum.map(top, fn {label, count} -> entry(label, count, filter.(label)) end) ++
      if(rest_count > 0, do: [entry("Other", rest_count, nil)], else: [])
  end

  defp entry(label, count, filter), do: %{label: label, count: count, filter: filter}

  defp condition_key(nil), do: "none"
  defp condition_key(condition), do: Atom.to_string(condition)

  defp condition_label(nil), do: "Not graded"
  defp condition_label(condition), do: Condition.description(condition)
end
