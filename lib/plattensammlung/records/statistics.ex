defmodule Plattensammlung.Records.Statistics do
  @moduledoc """
  Implementation of the generic action `Album.statistics`: key figures and
  breakdowns of the collection.

  Totals are computed by the database with `Ash.count/2` and `Ash.sum/3`
  (aggregate queries). Breakdowns (genres, decades, …) are counted in Elixir,
  which is plenty fast for a private collection and keeps genre lists simple.
  """
  use Ash.Resource.Actions.Implementation

  require Ash.Query

  alias Plattensammlung.Records
  alias Plattensammlung.Records.{Album, Artist, Condition, Copy}

  @top 8

  @impl true
  def run(_input, _opts, context) do
    # Same actor and authorization as the calling action
    opts = Ash.Context.to_opts(context)

    with {:ok, albums} <- Ash.count(owned_albums(), opts),
         {:ok, copies} <- Ash.count(Copy, opts),
         {:ok, wishlist} <- Ash.count(Ash.Query.filter(Album, wanted == true), opts),
         {:ok, artists} <- Ash.count(Ash.Query.filter(Artist, exists(albums.copies, true)), opts),
         {:ok, value} <- Ash.sum(Copy, :purchase_price, opts),
         {:ok, priced} <- Ash.count(Ash.Query.filter(Copy, not is_nil(purchase_price)), opts),
         {:ok, collection} <- Records.list_collection(opts),
         {:ok, all_copies} <- Ash.read(Copy, opts) do
      {:ok,
       %{
         albums: albums,
         copies: copies,
         wishlist: wishlist,
         artists: artists,
         value: value || Decimal.new(0),
         priced_copies: priced,
         genres: genres(collection),
         decades: decades(collection),
         conditions: conditions(all_copies),
         top_artists: top_artists(collection)
       }}
    end
  end

  defp owned_albums, do: Ash.Query.filter(Album, exists(copies, true))

  # Each breakdown is a list of %{label, count}, ready for bars and for JSON

  defp genres(albums) do
    albums
    |> Enum.flat_map(& &1.genres)
    |> Enum.frequencies()
    |> top_with_rest()
  end

  defp decades(albums) do
    albums
    |> Enum.map(fn
      %{year: nil} -> "Unbekannt"
      %{year: year} -> "#{div(year, 10) * 10}er"
    end)
    |> Enum.frequencies()
    # Chronological, unknown last
    |> Enum.sort_by(fn {label, _} -> {label == "Unbekannt", label} end)
    |> to_entries()
  end

  defp conditions(copies) do
    counts = copies |> Enum.map(& &1.media_condition) |> Enum.frequencies()

    # Goldmine order from best to worst, only grades that occur
    (Condition.values() ++ [nil])
    |> Enum.filter(&Map.has_key?(counts, &1))
    |> Enum.map(&%{label: condition_label(&1), count: counts[&1]})
  end

  defp top_artists(albums) do
    albums
    |> Enum.map(&to_string(&1.artist.name))
    |> Enum.frequencies()
    |> Enum.sort_by(fn {name, count} -> {-count, name} end)
    |> Enum.take(@top)
    |> to_entries()
  end

  # Largest first; everything after the top entries is folded into "Andere"
  defp top_with_rest(frequencies) do
    {top, rest} =
      frequencies
      |> Enum.sort_by(fn {label, count} -> {-count, label} end)
      |> Enum.split(@top)

    rest_count = rest |> Enum.map(&elem(&1, 1)) |> Enum.sum()
    to_entries(top) ++ if(rest_count > 0, do: [%{label: "Andere", count: rest_count}], else: [])
  end

  defp to_entries(pairs),
    do: Enum.map(pairs, fn {label, count} -> %{label: label, count: count} end)

  defp condition_label(nil), do: "Ohne Angabe"
  defp condition_label(condition), do: Condition.description(condition)
end
