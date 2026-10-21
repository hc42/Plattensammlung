defmodule PlattensammlungWeb.AlbumLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Arrange/assert calls below skip authorization; the views run as this user
  setup :register_and_sign_in_user

  alias Plattensammlung.Records

  describe "Index" do
    setup do
      owned =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{year: 1969}, authorize?: false)

      wanted = Records.add_to_wishlist!("Can", "Tago Mago", authorize?: false)
      %{owned: owned, wanted: wanted}
    end

    test "collection lists owned albums only", %{conn: conn, owned: owned, wanted: wanted} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(view, "#albums-#{owned.id}")
      refute has_element?(view, "#albums-#{wanted.id}")
    end

    test "wishlist lists wanted albums only", %{conn: conn, owned: owned, wanted: wanted} do
      {:ok, view, _html} = live(conn, ~p"/wishlist")

      assert has_element?(view, "#albums-#{wanted.id}")
      refute has_element?(view, "#albums-#{owned.id}")
    end

    test "search filters by artist and updates the URL", %{conn: conn, owned: owned} do
      Records.add_to_collection!("Pink Floyd", "Animals", authorize?: false)
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#search-form", %{q: "beatles"}) |> render_change()

      assert_patch(view, ~p"/?q=beatles")
      assert has_element?(view, "#albums-#{owned.id}")
      refute has_element?(view, "#albums a", "Animals")
    end
  end

  describe "Form" do
    test "quick capture adds an album to the collection", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view
      |> form("#album-form", album: %{artist_name: "Kraftwerk", title: "Autobahn"})
      |> render_submit()

      [album] = Records.search_albums!("Autobahn", :collection, authorize?: false)
      assert_redirect(view, ~p"/albums/#{album}")
    end

    test "switching to wishlist adds a wanted album", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view |> form("#album-form", mode: "wishlist") |> render_change()

      view
      |> form("#album-form", album: %{artist_name: "Can", title: "Ege Bamyasi"})
      |> render_submit()

      assert [%{wanted: true}] = Records.search_albums!("Ege", :wishlist, authorize?: false)
    end

    test "shows validation errors for missing title", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view
      |> form("#album-form", album: %{artist_name: "Kraftwerk", title: ""})
      |> render_submit()

      assert has_element?(view, "#album-form .text-error")
      assert Records.search_albums!(nil, nil, authorize?: false) == []
    end

    test "warns about duplicates", %{conn: conn} do
      Records.add_to_collection!("The Beatles", "Abbey Road", authorize?: false)
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view
      |> form("#album-form", album: %{artist_name: "the beatles", title: "abbey road"})
      |> render_change()

      assert has_element?(view, "#duplicate-warning")
    end

    test "edits album with genres as comma separated text", %{conn: conn} do
      album = Records.add_to_collection!("The Beatles", "Abbey Road", authorize?: false)
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}/edit")

      view
      |> form("#album-form", album: %{genres: "Rock, Pop", year: "1969"})
      |> render_submit()

      assert %{genres: ["Rock", "Pop"], year: 1969} =
               Records.get_album!(album.id, authorize?: false)
    end
  end

  describe "Show" do
    test "toggles the wishlist for an album that is not owned", %{conn: conn} do
      album = Records.add_to_wishlist!("Can", "Tago Mago", authorize?: false)
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

      view |> element("#toggle-wanted") |> render_click()

      refute Records.get_album!(album.id, authorize?: false).wanted
    end

    test "adding a copy via the copy form marks the album as owned", %{conn: conn} do
      album = Records.add_to_wishlist!("Can", "Tago Mago", authorize?: false)
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}/copies/new")

      view
      |> form("#copy-form", copy: %{format: "2LP", media_condition: "near_mint"})
      |> render_submit()

      assert_redirect(view, ~p"/albums/#{album}")
      album = Records.get_album!(album.id, load: [:owned, :copies], authorize?: false)
      assert album.owned
      refute album.wanted
      assert [%{format: "2LP", media_condition: :near_mint}] = album.copies
    end

    test "deletes a copy and the album", %{conn: conn} do
      album = Records.add_to_collection!("The Beatles", "Abbey Road", authorize?: false)
      [copy] = Ash.load!(album, :copies, authorize?: false).copies
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

      view |> element("#delete-copy-#{copy.id}") |> render_click()
      refute has_element?(view, "#copy-#{copy.id}")

      view |> element("#delete-album") |> render_click()
      assert_redirect(view, ~p"/")
      assert {:error, _} = Records.get_album(album.id, authorize?: false)
    end
  end
end
