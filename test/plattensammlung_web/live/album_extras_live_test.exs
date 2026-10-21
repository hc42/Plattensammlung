defmodule PlattensammlungWeb.AlbumExtrasLiveTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest

  alias Plattensammlung.{Accounts, LookupStub, Records}

  @moduletag :capture_log

  # Arrange/assert calls skip authorization; the views run as the signed-in user
  setup :register_and_sign_in_user

  describe "all albums" do
    setup do
      owned = Records.add_to_collection!("The Beatles", "Abbey Road", authorize?: false)
      wanted = Records.add_to_wishlist!("Can", "Tago Mago", authorize?: false)
      loose = Records.add_to_wishlist!("Kraftwerk", "Autobahn", authorize?: false)
      Records.unmark_wanted!(loose, authorize?: false)

      %{owned: owned, wanted: wanted, loose: loose}
    end

    test "shows every album", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/albums")

      for album <- [ctx.owned, ctx.wanted, ctx.loose] do
        assert has_element?(view, "#albums-#{album.id}")
      end
    end

    test "filters albums without copy and wish", %{conn: conn} = ctx do
      {:ok, view, _html} = live(conn, ~p"/albums")

      view |> element("#filter-unassigned") |> render_click()
      assert_patch(view, ~p"/albums?show=unassigned")

      assert has_element?(view, "#albums-#{ctx.loose.id}", "nicht zugeordnet")
      refute has_element?(view, "#albums-#{ctx.owned.id}")
      refute has_element?(view, "#albums-#{ctx.wanted.id}")
    end

    test "the collection links to all albums", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#all-albums-link")
    end
  end

  describe "match page" do
    setup do
      LookupStub.install()
      album = Records.add_to_collection!("The Beatles", "Abbey Road", authorize?: false)
      %{album: album}
    end

    test "previews and fills missing data", %{conn: conn, album: album} do
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}/match")
      render_async(view)

      assert view |> element("#changes-0") |> render() =~ "Jahr"

      view |> element("#fill-0") |> render_click()
      assert_redirect(view, ~p"/albums/#{album}")

      assert %{year: 1969, discogs_master_id: 24047} =
               Records.get_album!(album.id, authorize?: false)
    end

    test "a scanned barcode fills the copy's pressing details", %{conn: conn, album: album} do
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}/match")
      render_async(view)

      view
      |> element("#match-scanner")
      |> render_hook("scanned", %{code: LookupStub.abbey_road_barcode()})

      render_async(view)

      # Default target: the copy without barcode
      assert has_element?(view, "#copy-target-form")
      assert view |> element("#copy-changes-0") |> render() =~ "Barcode"

      view |> element("#fill-0") |> render_click()
      assert_redirect(view, ~p"/albums/#{album}")

      [copy] = Ash.load!(album, :copies, authorize?: false).copies
      assert copy.barcode == LookupStub.abbey_road_barcode()
    end

    test "searches with a custom query", %{conn: conn, album: album} do
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}/match")
      render_async(view)

      view |> form("#match-form", query: LookupStub.abbey_road_barcode()) |> render_submit()
      render_async(view)

      assert has_element?(view, "#match-0", "Vinyl, LP, Album")
    end
  end

  describe "cover upload" do
    setup do
      %{album: Records.add_to_collection!("Can", "Tago Mago", authorize?: false)}
    end

    test "an uploaded image becomes the cover", %{conn: conn, album: album} do
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

      png = <<0x89, "PNG", 0x0D, 0x0A, 0x1A, 0x0A, "image-data">>

      upload =
        file_input(view, "#cover-form", :cover, [
          %{name: "cover.png", content: png, type: "image/png"}
        ])

      render_upload(upload, "cover.png")

      assert %{cover_url: "/covers/" <> _} = Records.get_album!(album.id, authorize?: false)
      assert has_element?(view, "#remove-cover")
    end

    test "other file types are refused", %{conn: conn, album: album} do
      {:ok, view, _html} = live(conn, ~p"/albums/#{album}")

      upload =
        file_input(view, "#cover-form", :cover, [
          %{name: "notes.txt", content: "hello", type: "text/plain"}
        ])

      assert {:error, [[_ref, :not_accepted]]} = render_upload(upload, "notes.txt")
      assert Records.get_album!(album.id, authorize?: false).cover_url == nil
    end
  end

  describe "passkey names" do
    setup %{user: user} do
      passkey =
        Accounts.register_passkey!(
          %{name: "Altes Handy", credential_id: "cred", public_key: "key", sign_count: 0},
          actor: user
        )

      %{passkey: passkey}
    end

    test "can be renamed on the account page", %{conn: conn, passkey: passkey, user: user} do
      {:ok, view, _html} = live(conn, ~p"/account")

      view |> element("#rename-passkey-#{passkey.id}") |> render_click()

      view
      |> form("#rename-passkey-form-#{passkey.id}", name: "  iPhone 17  ")
      |> render_submit()

      assert has_element?(view, "#passkey-#{passkey.id}", "iPhone 17")
      assert [%{name: "iPhone 17"}] = Accounts.list_passkeys!(actor: user)
    end

    test "only the owner may rename", %{passkey: passkey} do
      other = user_fixture("other@example.com")

      assert {:error, %Ash.Error.Forbidden{}} =
               Accounts.rename_passkey(passkey, "Fremd", actor: other)
    end
  end
end
