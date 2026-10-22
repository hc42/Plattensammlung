defmodule PlattensammlungWeb.RecordsApiTest do
  use PlattensammlungWeb.ConnCase, async: true

  alias Plattensammlung.{LookupStub, Records}

  @json_api "application/vnd.api+json"

  # Requests authenticate with an API key; arrange/assert calls skip authorization
  setup %{conn: conn} do
    user = user_fixture()
    {api_key, _} = api_key_fixture(user)

    conn =
      conn
      |> put_req_header("accept", @json_api)
      |> put_req_header("content-type", @json_api)
      |> put_req_header("authorization", "Bearer " <> api_key)

    %{conn: conn, user: user}
  end

  describe "authentication" do
    test "requests without an API key are forbidden", %{conn: conn} do
      conn = delete_req_header(conn, "authorization")

      body = conn |> get(~p"/api/json/albums") |> json_response(403)
      assert [%{"code" => "forbidden"}] = body["errors"]
    end

    test "an unknown API key is rejected", %{conn: conn} do
      conn = put_req_header(conn, "authorization", "Bearer plattensammlung_nope")

      assert conn |> get(~p"/api/json/albums") |> response(401)
    end

    test "an expired API key is rejected", %{conn: conn} do
      {expired, _} = api_key_fixture(user_fixture("expired@example.com"), DateTime.utc_now())
      conn = put_req_header(conn, "authorization", "Bearer " <> expired)

      assert conn |> get(~p"/api/json/albums") |> response(401)
    end

    test "the OpenAPI spec is readable without a key", %{conn: conn} do
      conn = delete_req_header(conn, "authorization")

      assert conn |> get(~p"/api/json/open_api") |> response(200)
    end
  end

  describe "GET /api/json/albums" do
    setup %{user: user} do
      Records.add_to_collection!("The Beatles", "Abbey Road", %{year: 1969}, actor: user)
      Records.add_to_wishlist!("Can", "Tago Mago", actor: user)
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

  # Generic actions: the arguments sit directly under "data", the answer is the
  # album as plain JSON (no JSON:API envelope)
  describe "POST /api/json/albums/collection" do
    test "creates album, artist and copy", %{conn: conn} do
      payload = %{
        data: %{
          artist_name: "Kraftwerk",
          title: "Autobahn",
          year: 1974,
          copy: %{format: ["LP"], media_condition: "very_good_plus"}
        }
      }

      body = conn |> post(~p"/api/json/albums/collection", payload) |> json_response(201)

      assert %{"title" => "Autobahn", "owned" => true, "id" => id} = body

      album = Records.get_album!(id, load: [:artist, :copies], authorize?: false)
      assert to_string(album.artist.name) == "Kraftwerk"
      assert [%{format: ["LP"], media_condition: :very_good_plus}] = album.copies
    end

    test "reports missing required fields", %{conn: conn} do
      payload = %{data: %{title: "Autobahn"}}

      body = conn |> post(~p"/api/json/albums/collection", payload) |> json_response(400)

      assert [%{"code" => "required", "source" => %{"pointer" => "/data/artist_name"}}] =
               body["errors"]
    end
  end

  describe "wishlist" do
    test "adds to and removes from the wishlist", %{conn: conn} do
      payload = %{data: %{artist_name: "Can", title: "Ege Bamyasi"}}
      body = conn |> post(~p"/api/json/albums/wishlist", payload) |> json_response(201)
      id = body["id"]
      assert body["wanted"] == true

      patch_body = %{data: %{type: "album", id: id, attributes: %{}}}
      body = conn |> patch(~p"/api/json/albums/#{id}/unwanted", patch_body) |> json_response(200)

      assert body["data"]["attributes"]["wanted"] == false
    end
  end

  describe "copies" do
    test "adding a copy marks the album as owned", %{conn: conn, user: user} do
      album = Records.add_to_wishlist!("Can", "Tago Mago", actor: user)

      payload = %{
        data: %{
          type: "copy",
          attributes: %{album_id: album.id, format: ["2LP"], notes: "Regal A"}
        }
      }

      conn |> post(~p"/api/json/copies", payload) |> json_response(201)

      assert %{wanted: false, owned: true} =
               Records.get_album!(album.id, load: [:owned, :wanted], actor: user)
    end

    test "lists the copies of an album", %{conn: conn, user: user} do
      album =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{copy: %{label: "Apple"}},
          actor: user
        )

      body = conn |> get(~p"/api/json/albums/#{album.id}/copies") |> json_response(200)

      assert [%{"type" => "copy", "attributes" => %{"label" => "Apple"}}] = body["data"]
    end
  end

  test "PATCH updates album and copy", %{conn: conn, user: user} do
    album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
    [copy] = Ash.load!(album, :copies, authorize?: false).copies

    album_patch = %{
      data: %{type: "album", id: album.id, attributes: %{year: 1969, genres: ["Rock"]}}
    }

    body = conn |> patch(~p"/api/json/albums/#{album.id}", album_patch) |> json_response(200)
    assert %{"year" => 1969, "genres" => ["Rock"], "owned" => true} = body["data"]["attributes"]

    copy_patch = %{data: %{type: "copy", id: copy.id, attributes: %{notes: "Regal B"}}}
    body = conn |> patch(~p"/api/json/copies/#{copy.id}", copy_patch) |> json_response(200)
    assert body["data"]["attributes"]["notes"] == "Regal B"
  end

  test "purchase date and notes of someone else's copy are left out", %{conn: conn, user: user} do
    alice = user_fixture("alice@example.com")

    album =
      Records.add_to_collection!(
        "The Beatles",
        "Abbey Road",
        %{copy: %{label: "Apple", notes: "Geheim", purchased_on: ~D[2019-05-03]}},
        actor: alice
      )

    [copy] = Ash.load!(album, :copies, authorize?: false).copies

    for path <- [~p"/api/json/copies/#{copy.id}", ~p"/api/json/albums/#{album.id}?include=copies"] do
      body = conn |> get(path) |> response(200)

      assert body =~ "Apple"
      refute body =~ "Geheim"
      refute body =~ "2019-05-03"
    end

    # The owner still sees everything
    own =
      Records.add_to_collection!("Can", "Tago Mago", %{copy: %{notes: "Meins"}}, actor: user)

    [own_copy] = Ash.load!(own, :copies, authorize?: false).copies
    body = conn |> get(~p"/api/json/copies/#{own_copy.id}") |> json_response(200)
    assert body["data"]["attributes"]["notes"] == "Meins"
  end

  test "DELETE …/mine removes the own entry, the album goes once no one has it",
       %{conn: conn, user: user} do
    album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
    Records.mark_wanted!(album, actor: user_fixture("other@example.com"))

    # Someone else still wants it: a direct delete is refused
    conn |> delete(~p"/api/json/albums/#{album.id}") |> response(403)

    conn |> delete(~p"/api/json/albums/#{album.id}/mine") |> response(200)
    assert %{owned: false} = Records.get_album!(album.id, load: [:owned], actor: user)
  end

  test "GET /api/json/albums/lookup searches external catalogs", %{conn: conn} do
    LookupStub.install()

    body = conn |> get(~p"/api/json/albums/lookup?query=0602547288530") |> json_response(200)

    assert [%{"source" => "discogs", "title" => "Abbey Road", "year" => 1969}] = body
  end

  test "GET /api/json/albums/statistics returns key figures", %{conn: conn, user: user} do
    Records.add_to_collection!("The Beatles", "Abbey Road", %{genres: ["Rock"]}, actor: user)

    body = conn |> get(~p"/api/json/albums/statistics") |> json_response(200)

    assert %{"albums" => 1, "copies" => 1, "genres" => [%{"label" => "Rock", "count" => 1}]} =
             body
  end

  test "the OpenAPI spec documents the routes", %{conn: conn} do
    # The spec is JSON but sent without a content-type header
    spec =
      conn |> get(~p"/api/json/open_api") |> response(200) |> Phoenix.json_library().decode!()

    assert Map.has_key?(spec["paths"], "/api/json/albums/collection")
    assert Map.has_key?(spec["paths"], "/api/json/albums/lookup")
  end
end
