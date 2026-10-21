defmodule PlattensammlungWeb.RecordsApiTest do
  use PlattensammlungWeb.ConnCase, async: true

  alias Plattensammlung.{LookupStub, Records}

  @json_api "application/vnd.api+json"

  setup %{conn: conn} do
    conn =
      conn
      |> put_req_header("accept", @json_api)
      |> put_req_header("content-type", @json_api)

    %{conn: conn}
  end

  describe "GET /api/json/albums" do
    setup do
      Records.add_to_collection!("The Beatles", "Abbey Road", %{year: 1969})
      Records.add_to_wishlist!("Can", "Tago Mago")
      :ok
    end

    test "lists albums with aggregates and the included artist", %{conn: conn} do
      body = conn |> get(~p"/api/json/albums?include=artist") |> json_response(200)

      assert [abbey, tago] = body["data"]
      assert abbey["attributes"]["title"] == "Abbey Road"
      assert abbey["attributes"]["owned"] == true
      assert abbey["attributes"]["copy_count"] == 1
      assert tago["attributes"]["wanted"] == true

      artist_names =
        for %{"type" => "artist"} = a <- body["included"], do: a["attributes"]["name"]

      assert Enum.sort(artist_names) == ["Can", "The Beatles"]
    end

    test "filters by query and status", %{conn: conn} do
      titles = fn path ->
        conn
        |> get(path)
        |> json_response(200)
        |> Map.fetch!("data")
        |> Enum.map(& &1["attributes"]["title"])
      end

      assert titles.(~p"/api/json/albums?query=beatles") == ["Abbey Road"]
      assert titles.(~p"/api/json/albums?status=wishlist") == ["Tago Mago"]
      assert titles.(~p"/api/json/albums?status=collection") == ["Abbey Road"]
    end
  end

  describe "POST /api/json/albums/collection" do
    test "creates album, artist and copy", %{conn: conn} do
      payload = %{
        data: %{
          type: "album",
          attributes: %{
            artist_name: "Kraftwerk",
            title: "Autobahn",
            year: 1974,
            copy: %{format: "LP", media_condition: "very_good_plus"}
          }
        }
      }

      body = conn |> post(~p"/api/json/albums/collection", payload) |> json_response(201)

      assert body["data"]["attributes"]["title"] == "Autobahn"
      assert body["data"]["attributes"]["owned"] == true

      album = Records.get_album!(body["data"]["id"], load: [:artist, :copies])
      assert to_string(album.artist.name) == "Kraftwerk"
      assert [%{format: "LP", media_condition: :very_good_plus}] = album.copies
    end

    test "reports missing required fields", %{conn: conn} do
      payload = %{data: %{type: "album", attributes: %{title: "Autobahn"}}}

      body = conn |> post(~p"/api/json/albums/collection", payload) |> json_response(400)

      assert [%{"code" => "required", "source" => %{"pointer" => "/data/attributes/artist_name"}}] =
               body["errors"]
    end
  end

  describe "wishlist" do
    test "adds to and removes from the wishlist", %{conn: conn} do
      payload = %{data: %{type: "album", attributes: %{artist_name: "Can", title: "Ege Bamyasi"}}}
      body = conn |> post(~p"/api/json/albums/wishlist", payload) |> json_response(201)
      id = body["data"]["id"]
      assert body["data"]["attributes"]["wanted"] == true

      patch_body = %{data: %{type: "album", id: id, attributes: %{}}}
      body = conn |> patch(~p"/api/json/albums/#{id}/unwanted", patch_body) |> json_response(200)

      assert body["data"]["attributes"]["wanted"] == false
    end
  end

  describe "copies" do
    test "adding a copy marks the album as owned", %{conn: conn} do
      album = Records.add_to_wishlist!("Can", "Tago Mago")

      payload = %{
        data: %{
          type: "copy",
          attributes: %{album_id: album.id, format: "2LP", location: "Regal A"}
        }
      }

      conn |> post(~p"/api/json/copies", payload) |> json_response(201)

      assert %{wanted: false, owned: true} = Records.get_album!(album.id, load: [:owned])
    end

    test "lists the copies of an album", %{conn: conn} do
      album = Records.add_to_collection!("The Beatles", "Abbey Road", %{copy: %{label: "Apple"}})

      body = conn |> get(~p"/api/json/albums/#{album.id}/copies") |> json_response(200)

      assert [%{"type" => "copy", "attributes" => %{"label" => "Apple"}}] = body["data"]
    end
  end

  test "PATCH updates album and copy", %{conn: conn} do
    album = Records.add_to_collection!("The Beatles", "Abbey Road")
    [copy] = Ash.load!(album, :copies).copies

    album_patch = %{
      data: %{type: "album", id: album.id, attributes: %{year: 1969, genres: ["Rock"]}}
    }

    body = conn |> patch(~p"/api/json/albums/#{album.id}", album_patch) |> json_response(200)
    assert %{"year" => 1969, "genres" => ["Rock"], "owned" => true} = body["data"]["attributes"]

    copy_patch = %{data: %{type: "copy", id: copy.id, attributes: %{location: "Regal B"}}}
    body = conn |> patch(~p"/api/json/copies/#{copy.id}", copy_patch) |> json_response(200)
    assert body["data"]["attributes"]["location"] == "Regal B"
  end

  test "DELETE removes an album", %{conn: conn} do
    album = Records.add_to_collection!("The Beatles", "Abbey Road")

    conn |> delete(~p"/api/json/albums/#{album.id}") |> response(200)

    assert {:error, _} = Records.get_album(album.id)
  end

  test "GET /api/json/albums/lookup searches external catalogs", %{conn: conn} do
    LookupStub.install()

    body = conn |> get(~p"/api/json/albums/lookup?query=0602547288530") |> json_response(200)

    assert [%{"source" => "discogs", "title" => "Abbey Road", "year" => 1969}] = body
  end

  test "the OpenAPI spec documents the routes", %{conn: conn} do
    # The spec is JSON but sent without a content-type header
    spec =
      conn |> get(~p"/api/json/open_api") |> response(200) |> Phoenix.json_library().decode!()

    assert Map.has_key?(spec["paths"], "/api/json/albums/collection")
    assert Map.has_key?(spec["paths"], "/api/json/albums/lookup")
  end
end
