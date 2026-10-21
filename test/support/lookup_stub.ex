defmodule Plattensammlung.LookupStub do
  @moduledoc """
  Fake Discogs, MusicBrainz and cover image responses for tests.

      Plattensammlung.LookupStub.install()
      Plattensammlung.LookupStub.install(discogs: :empty)
  """
  import Plug.Conn

  @abbey_road_barcode "0602547288530"

  def abbey_road_barcode, do: @abbey_road_barcode

  @doc """
  Options: `discogs:` and `musicbrainz:` each `:ok` (default), `:empty` or `:error`.
  """
  def install(opts \\ []) do
    Req.Test.stub(Plattensammlung.Lookup, fn conn ->
      conn = fetch_query_params(conn)
      route(conn, conn.host, opts)
    end)
  end

  defp route(conn, "api.discogs.com", opts) do
    case {Keyword.get(opts, :discogs, :ok), conn.request_path, conn.query_params} do
      {:error, _path, _params} ->
        send_resp(conn, 500, "")

      {:empty, _path, _params} ->
        Req.Test.json(conn, %{"results" => []})

      {:ok, "/database/search", %{"barcode" => @abbey_road_barcode}} ->
        Req.Test.json(conn, %{"results" => [discogs_release()]})

      {:ok, "/database/search", %{"barcode" => _other}} ->
        Req.Test.json(conn, %{"results" => []})

      {:ok, "/database/search", %{"type" => "master"}} ->
        Req.Test.json(conn, %{"results" => [discogs_master_search()]})

      {:ok, "/masters/24047", _params} ->
        Req.Test.json(conn, discogs_master())
    end
  end

  defp route(conn, "musicbrainz.org", opts) do
    case {Keyword.get(opts, :musicbrainz, :ok), conn.request_path} do
      {:error, _path} -> send_resp(conn, 503, "")
      {:empty, "/ws/2/release-group"} -> Req.Test.json(conn, %{"release-groups" => []})
      {:empty, "/ws/2/release"} -> Req.Test.json(conn, %{"releases" => []})
      {:ok, "/ws/2/release-group"} -> Req.Test.json(conn, %{"release-groups" => mb_groups()})
      {:ok, "/ws/2/release"} -> Req.Test.json(conn, %{"releases" => [mb_release()]})
    end
  end

  # Cover images
  defp route(conn, _host, _opts) do
    conn
    |> put_resp_content_type("image/jpeg", nil)
    |> send_resp(200, "fake-jpeg-bytes")
  end

  defp discogs_release do
    %{
      "id" => 12_345_678,
      "master_id" => 24047,
      "title" => "The Beatles - Abbey Road",
      "year" => "2019",
      "genre" => ["Rock"],
      "label" => ["Apple Records", "Universal"],
      "catno" => "0602547288530",
      "country" => "Europe",
      "format" => ["Vinyl", "LP", "Album", "Reissue"],
      "cover_image" => "https://i.discogs.com/release.jpg",
      "thumb" => "https://i.discogs.com/release-thumb.jpg"
    }
  end

  defp discogs_master_search do
    %{
      "id" => 24047,
      "title" => "The Beatles - Abbey Road",
      "year" => "1969",
      "genre" => ["Rock", "Pop"],
      "cover_image" => "https://i.discogs.com/master.jpg",
      "thumb" => "https://i.discogs.com/master-thumb.jpg"
    }
  end

  defp discogs_master do
    %{
      "id" => 24047,
      "title" => "Abbey Road",
      "year" => 1969,
      "artists" => [%{"name" => "The Beatles"}],
      "genres" => ["Rock", "Pop"],
      "images" => [%{"type" => "primary", "uri" => "https://i.discogs.com/master.jpg"}]
    }
  end

  defp mb_groups do
    [
      # Same album as on Discogs, merged away
      %{
        "id" => "9162580e-5df4-32de-80cc-f45a8d8a9b1d",
        "title" => "Abbey Road",
        "first-release-date" => "1969-09-26",
        "artist-credit" => [%{"name" => "The Beatles"}]
      },
      %{
        "id" => "c1e1e5a1-0000-4000-8000-000000000001",
        "title" => "Abbey Road Revisited",
        "first-release-date" => "2006",
        "artist-credit" => [%{"name" => "Various", "joinphrase" => " & "}, %{"name" => "Friends"}]
      }
    ]
  end

  defp mb_release do
    %{
      "id" => "c1e1e5a1-0000-4000-8000-000000000002",
      "title" => "Abbey Road",
      "date" => "2019-09-27",
      "country" => "XE",
      "artist-credit" => [%{"name" => "The Beatles"}],
      "release-group" => %{
        "id" => "9162580e-5df4-32de-80cc-f45a8d8a9b1d",
        "title" => "Abbey Road"
      },
      "label-info" => [%{"catalog-number" => "0602547288530", "label" => %{"name" => "Apple"}}],
      "media" => [%{"format" => "12\" Vinyl"}]
    }
  end
end
