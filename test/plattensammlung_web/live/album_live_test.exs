defmodule PlattensammlungWeb.AlbumLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  # Arrange/assert calls below skip authorization; the views run as this user
  setup :register_and_sign_in_user

  alias Plattensammlung.Records

  describe "Index" do
    setup %{user: user} do
      owned =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{year: 1969}, actor: user)

      wanted = Records.add_to_wishlist!("Can", "Tago Mago", actor: user)
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

    test "search filters by artist and updates the URL", %{conn: conn, owned: owned, user: user} do
      Records.add_to_collection!("Pink Floyd", "Animals", actor: user)
      {:ok, view, _html} = live(conn, ~p"/")

      view |> form("#search-form", %{q: "beatles"}) |> render_change()

      assert_patch(view, ~p"/?q=beatles")
      assert has_element?(view, "#albums-#{owned.id}")
      refute has_element?(view, "#albums a", "Animals")
    end
  end

  describe "Form" do
    test "quick capture adds an album to the collection", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view
      |> form("#album-form", album: %{artist_name: "Kraftwerk", title: "Autobahn"})
      |> render_submit()

      [album] = Records.search_albums!("Autobahn", :collection, actor: user)
      assert_redirect(view, ~p"/albums/#{album}")
    end

    test "switching to wishlist adds a wanted album", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view |> form("#album-form", mode: "wishlist") |> render_change()

      view
      |> form("#album-form", album: %{artist_name: "Can", title: "Ege Bamyasi"})
      |> render_submit()

      assert [album] = Records.search_albums!("Ege", :wishlist, load: [:wanted], actor: user)
      assert album.wanted
    end

    test "shows validation errors for missing title", %{conn: conn, user: user} do
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view
      |> form("#album-form", album: %{artist_name: "Kraftwerk", title: ""})
      |> render_submit()

      assert has_element?(view, "#album-form .text-error")
      assert Records.search_albums!(nil, nil, actor: user) == []
    end

    test "warns about duplicates, also of other collectors", %{conn: conn, user: user} do
      Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
      Records.add_to_wishlist!("Can", "Tago Mago", actor: user_fixture("other@example.com"))
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      view
      |> form("#album-form", album: %{artist_name: "the beatles", title: "abbey road"})
      |> render_change()

      assert has_element?(view, "#duplicate-warning", "in your collection")

      view
      |> form("#album-form", album: %{artist_name: "can", title: "tago mago"})
      |> render_change()

      assert has_element?(view, "#duplicate-warning", "with other collectors")
    end

    test "edits optional fields and genre tags", %{conn: conn, user: user} do
      Records.add_to_collection!("Pink Floyd", "Animals", %{genres: ["Rock"]}, actor: user)
      album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}/edit")

      assert has_element?(view, "#cover-preview")
      refute has_element?(view, "#field-year")

      view |> element("#add-year") |> render_click()
      view |> element("#add-genres") |> render_click()

      # Enter in the tag field submits only the small genre form; "rock" takes
      # the spelling of the existing genre "Rock"
      view |> element("#genres-entry") |> render_submit(%{field: "genres", tag: "rock, Pop"})
      view |> element("#genres-entry") |> render_submit(%{field: "genres", tag: "Jazz"})
      view |> element("#genres-tag-jazz button") |> render_click()

      assert has_element?(view, "#genres-tag-rock")
      assert has_element?(view, "#genres-tag-pop")
      refute has_element?(view, "#genres-tag-jazz")

      view |> form("#album-form", album: %{year: "1969"}) |> render_submit()

      assert %{genres: ["Rock", "Pop"], year: 1969} =
               Records.get_album!(album.id, authorize?: false)
    end

    test "removing an optional field clears its value", %{conn: conn, user: user} do
      album =
        Records.add_to_collection!("The Beatles", "Abbey Road", %{year: 1969, genres: ["Rock"]},
          actor: user
        )

      {:ok, view, _html} = live(conn, ~p"/albums/#{album}/edit")

      # Fields with a value are visible from the start
      assert has_element?(view, "#field-year")
      view |> element("#remove-year") |> render_click()
      view |> element("#remove-genres") |> render_click()
      assert has_element?(view, "#add-year")

      view |> form("#album-form") |> render_submit()

      assert %{year: nil, genres: []} = Records.get_album!(album.id, authorize?: false)
    end
  end

  describe "Show" do
    test "toggles the wishlist for an album that is not owned", %{conn: conn, user: user} do
      album = Records.add_to_wishlist!("Can", "Tago Mago", actor: user)
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

      view |> element("#toggle-wanted") |> render_click()

      refute Records.get_album!(album.id, load: [:wanted], actor: user).wanted
    end

    test "adding a copy via the copy form marks the album as owned", %{conn: conn, user: user} do
      album = Records.add_to_wishlist!("Can", "Tago Mago", actor: user)
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}/copies/new")

      # Optional fields appear only after their "+" button
      refute has_element?(view, "#field-format")
      view |> element("#add-format") |> render_click()
      # Format is a tag field: Enter in its entry adds the tag
      view |> element("#format-entry") |> render_submit(%{field: "format", tag: "2LP, Gatefold"})
      view |> element("#add-media_condition") |> render_click()

      view
      |> form("#copy-form", copy: %{media_condition: "near_mint"})
      |> render_submit()

      assert_redirect(view, ~p"/albums/#{album}")
      album = Records.get_album!(album.id, load: [:owned, :wanted, :copies], actor: user)
      assert album.owned
      refute album.wanted
      assert [%{format: ["2LP", "Gatefold"], media_condition: :near_mint}] = album.copies
    end

    test "deletes a copy, then the album no one has any more", %{conn: conn, user: user} do
      album = Records.add_to_collection!("The Beatles", "Abbey Road", actor: user)
      [copy] = Ash.load!(album, :copies, authorize?: false).copies
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

      view |> element("#delete-copy-#{copy.id}") |> render_click()
      refute has_element?(view, "#copy-#{copy.id}")

      view |> element("#remove-album") |> render_click()
      # Without copies the album was no longer in the collection: back to all albums
      assert_redirect(view, ~p"/albums")
      assert {:error, _} = Records.get_album(album.id, authorize?: false)
    end
  end
end
