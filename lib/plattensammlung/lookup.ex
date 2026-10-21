defmodule Plattensammlung.Lookup do
  @moduledoc """
  Finds albums in external catalogs (see ADR 0007).

  A query of 8 to 14 digits is treated as a barcode: the first source with a
  match wins (Discogs, then MusicBrainz). Any other query is a text search in
  all sources at once; results are merged album by album, Discogs first.
  """
  alias Plattensammlung.Lookup.{Discogs, MusicBrainz}
  alias Plattensammlung.Records.LookupResult

  require Logger

  @sources [Discogs, MusicBrainz]

  @doc "Sources that can be queried with the current configuration."
  def sources, do: Enum.filter(@sources, & &1.configured?())

  @spec search(String.t()) :: {:ok, [struct()]} | {:error, term()}
  def search(query) do
    query = String.trim(query)

    case barcode(query) do
      nil -> text_search(query)
      barcode -> barcode_search(barcode)
    end
  end

  @doc "Returns the normalized barcode if the query looks like one, otherwise nil."
  def barcode(query) do
    digits = String.replace(query, ~r/[\s-]/, "")
    if Regex.match?(~r/^\d{8,14}$/, digits), do: digits
  end

  @doc "Album attributes for `Records.add_to_collection/3` and friends."
  def album_attrs(%LookupResult{} = result) do
    Map.take(result, [
      :year,
      :genres,
      :cover_url,
      :discogs_master_id,
      :musicbrainz_release_group_id
    ])
  end

  @doc "Pressing details for a copy; empty when the result came from a text search."
  def copy_attrs(%LookupResult{} = result) do
    result
    |> Map.take([
      :barcode,
      :label,
      :catalog_number,
      :country,
      :pressing_year,
      :format,
      :discogs_release_id,
      :musicbrainz_release_id
    ])
    |> Map.reject(fn {_key, value} -> is_nil(value) end)
  end

  defp barcode_search(barcode) do
    sources()
    |> Enum.reduce_while({:ok, []}, fn source, acc ->
      case source.by_barcode(barcode) do
        {:ok, [_ | _] = results} -> {:halt, {:ok, results}}
        {:ok, []} -> {:cont, acc}
        {:error, reason} -> {:cont, log_error(source, reason, acc)}
      end
    end)
    |> to_structs()
  end

  defp text_search(""), do: {:ok, []}

  defp text_search(query) do
    sources()
    |> Task.async_stream(& &1.search(query), timeout: 20_000, on_timeout: :kill_task)
    |> Enum.zip(sources())
    |> Enum.reduce({:ok, []}, fn
      {{:ok, {:ok, results}}, _source}, {:ok, acc} -> {:ok, acc ++ results}
      {{:ok, {:ok, results}}, _source}, {:error, _reason} -> {:ok, results}
      {{:ok, {:error, reason}}, source}, acc -> log_error(source, reason, acc)
      {{:exit, reason}, source}, acc -> log_error(source, reason, acc)
    end)
    |> case do
      {:ok, results} -> to_structs({:ok, Enum.uniq_by(results, &album_key/1)})
      error -> error
    end
  end

  # Only fail when no source answered at all
  defp log_error(source, reason, acc) do
    Logger.warning("Lookup via #{inspect(source)} failed: #{inspect(reason)}")

    case acc do
      {:ok, []} -> {:error, reason}
      acc -> acc
    end
  end

  defp album_key(result) do
    {normalize(result.artist_name), normalize(result.title)}
  end

  defp normalize(nil), do: nil

  defp normalize(text) do
    text |> String.downcase() |> String.replace(~r/[^\p{L}\p{N}]+/u, " ") |> String.trim()
  end

  defp to_structs({:ok, results}) do
    {:ok,
     results
     |> Enum.reject(&(is_nil(&1.artist_name) or is_nil(&1.title)))
     |> Enum.map(&struct!(LookupResult, &1))}
  end

  defp to_structs(error), do: error
end
