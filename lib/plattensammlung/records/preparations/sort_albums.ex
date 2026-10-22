defmodule Plattensammlung.Records.Preparations.SortAlbums do
  @moduledoc """
  Order of `Album.search` (argument `order`, in the API `?order=artist`; the
  JSON:API `?sort=` still works on top):

    * `:title` – by title (default)
    * `:artist` – by the artist's sort name ("Beatles, The"), then year
    * `:year` – oldest first, albums without year last
    * `:added` – newest first: when the listed user (`owner_id`, default: the
      actor) added a copy or wish, otherwise when the album came into the catalog

  Title is always the last criterion, so the order is stable.
  """
  use Ash.Resource.Preparation

  @impl true
  def prepare(query, _opts, context) do
    owner = Ash.Query.get_argument(query, :owner_id) || (context.actor && context.actor.id)

    sort =
      case Ash.Query.get_argument(query, :order) do
        :artist -> [artist_sort_key: :asc, year: :asc_nils_last]
        :year -> [year: :asc_nils_last]
        :added -> [added_at: {%{owner_id: owner}, :desc}]
        _title -> []
      end

    Ash.Query.sort(query, sort ++ [title: :asc])
  end
end
