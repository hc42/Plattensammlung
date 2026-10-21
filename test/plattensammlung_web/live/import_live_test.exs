defmodule PlattensammlungWeb.ImportLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  # Failure scenarios log warnings on purpose
  @moduletag :capture_log

  import Phoenix.LiveViewTest

  alias Plattensammlung.{LookupStub, Records}

  setup do
    LookupStub.install()
    :ok
  end

  test "barcode lookup adds the album with its pressing to the collection", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/import")

    view |> form("#lookup-form", query: LookupStub.abbey_road_barcode()) |> render_submit()
    assert_patch(view, ~p"/import?q=#{LookupStub.abbey_road_barcode()}")
    render_async(view)

    assert has_element?(view, "#result-0")
    view |> element("#import-collection-0") |> render_click()

    [album] = Records.search_albums!("Abbey Road", :collection)
    assert_redirect(view, ~p"/albums/#{album}")

    album = Ash.load!(album, [:copies, :artist])
    assert to_string(album.artist.name) == "The Beatles"
    assert album.year == 1969
    assert album.discogs_master_id == 24047
    assert "/covers/" <> _ = album.cover_url

    assert [%{barcode: "0602547288530", label: "Apple Records", discogs_release_id: 12_345_678}] =
             album.copies
  end

  test "text lookup adds an album to the wishlist", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/import?q=beatles+abbey+road")
    render_async(view)

    view |> element("#import-wishlist-1") |> render_click()

    assert [%{title: title, wanted: true}] = Records.search_albums!(nil, :wishlist)
    assert to_string(title) == "Abbey Road Revisited"
  end

  test "marks albums that are already in the collection", %{conn: conn} do
    Records.add_to_collection!("The Beatles", "Abbey Road", %{copy: %{barcode: "0602547288530"}})

    {:ok, view, _html} = live(conn, ~p"/import?q=0602547288530")
    render_async(view)

    assert has_element?(view, "#owned-pressing")
    assert has_element?(view, "#result-0 a", "Hast du schon")
    refute has_element?(view, "#import-wishlist-0")
  end

  test "adding a known album from the results adds another copy", %{conn: conn} do
    album = Records.add_to_collection!("The Beatles", "Abbey Road")

    {:ok, view, _html} = live(conn, ~p"/import?q=0602547288530")
    render_async(view)
    view |> element("#import-collection-0") |> render_click()

    assert_redirect(view, ~p"/albums/#{album}")
    assert %{copy_count: 2} = Records.get_album!(album.id, load: [:copy_count])
  end

  test "a scanned barcode starts the lookup", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/import")

    view |> element("#barcode-scanner") |> render_hook("scanned", %{code: "0602547288530"})

    assert_patch(view, ~p"/import?q=0602547288530")
    render_async(view)
    assert has_element?(view, "#result-0")
  end

  test "an invalid scan is rejected", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/import")

    view |> element("#barcode-scanner") |> render_hook("scanned", %{code: "abc"})

    refute has_element?(view, "#lookup-loading")
  end

  test "shows an error when no source answers", %{conn: conn} do
    LookupStub.install(discogs: :error, musicbrainz: :error)

    {:ok, view, _html} = live(conn, ~p"/import?q=beatles")
    render_async(view)

    assert has_element?(view, "#lookup-error")
  end
end
