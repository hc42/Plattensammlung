defmodule PlattensammlungWeb.LocaleTest do
  use PlattensammlungWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Swoosh.TestAssertions

  alias PlattensammlungWeb.Locale

  describe "from_header/1" do
    test "picks the best supported language" do
      assert Locale.from_header("de-DE,de;q=0.9,en;q=0.8") == "de"
      assert Locale.from_header("en-US,en;q=0.9,de;q=0.8") == "en"
      assert Locale.from_header("fr-FR,fr;q=0.9,de;q=0.5") == "de"
      assert Locale.from_header("en;q=0.2, DE;q=0.7") == "de"
    end

    test "falls back to English" do
      assert Locale.from_header(nil) == "en"
      assert Locale.from_header("") == "en"
      assert Locale.from_header("fr,es;q=0.5") == "en"
      assert Locale.from_header("de;q=0") == "en"
      assert Locale.from_header("de;q=abc, ;;,") == "en"
    end
  end

  describe "pages" do
    setup :register_and_sign_in_user

    test "are English by default", %{conn: conn} do
      html = conn |> get(~p"/") |> html_response(200)
      assert html =~ ~s(lang="en")

      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#nav-collection", "Collection")
    end

    test "follow the browser language", %{conn: conn} do
      conn = put_req_header(conn, "accept-language", "de-DE,de;q=0.9,en;q=0.8")
      assert conn |> get(~p"/") |> html_response(200) =~ ~s(lang="de")

      {:ok, view, _html} = live(conn, ~p"/")
      assert has_element?(view, "#nav-collection", "Sammlung")
      assert page_title(view) =~ "Sammlung"
    end

    test "use the language chosen on the account page", %{conn: conn, user: user} do
      conn = put_req_header(conn, "accept-language", "de")
      {:ok, view, _html} = live(conn, ~p"/account")

      assert {:error, {:redirect, %{to: "/account"}}} =
               view |> form("#locale-form", locale: "en") |> render_change()

      user = Ash.reload!(user, authorize?: false)
      assert user.locale == "en"

      # The browser asks for German, the user's choice wins
      {:ok, view, _html} = live(sign_in_user(conn, user), ~p"/")
      assert has_element?(view, "#nav-collection", "Collection")
    end

    test "translate form errors", %{conn: conn} do
      conn = put_req_header(conn, "accept-language", "de")
      {:ok, view, _html} = live(conn, ~p"/albums/new")

      html =
        view
        |> form("#album-form", album: %{artist_name: "", title: String.duplicate("x", 201)})
        |> render_change()

      assert html =~ "darf höchstens 200 Zeichen lang sein"
    end
  end

  test "the magic link e-mail is in the language of the sign-in page", %{conn: conn} do
    conn = put_req_header(conn, "accept-language", "de")
    {:ok, view, _html} = live(conn, ~p"/sign-in")
    view |> form("#magic-link-form", email: "test@example.com") |> render_submit()

    assert_email_sent(fn email ->
      assert email.subject == "Dein Anmeldelink für die Plattensammlung"
    end)
  end

  test "every German translation is complete" do
    for domain <- ~w(default errors) do
      pot = Expo.PO.parse_file!("priv/gettext/#{domain}.pot")
      po = Expo.PO.parse_file!("priv/gettext/de/LC_MESSAGES/#{domain}.po")
      translated = Map.new(po.messages, &{Expo.Message.key(&1), &1})

      for message <- pot.messages do
        key = Expo.Message.key(message)
        translation = translated[key]

        assert translation, "missing German translation in #{domain}.po: #{inspect(key)}"

        refute Expo.Message.has_flag?(translation, "fuzzy"),
               "fuzzy in #{domain}.po: #{inspect(key)}"

        msgstrs =
          case translation do
            %Expo.Message.Singular{msgstr: msgstr} -> [msgstr]
            %Expo.Message.Plural{msgstr: msgstr} -> Map.values(msgstr)
          end

        assert Enum.all?(msgstrs, &(IO.iodata_to_binary(&1) != "")),
               "empty German translation in #{domain}.po: #{inspect(key)}"
      end
    end
  end
end
