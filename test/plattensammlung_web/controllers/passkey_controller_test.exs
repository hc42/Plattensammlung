defmodule PlattensammlungWeb.PasskeyControllerTest do
  # Not async: one test changes the global allowed_emails config
  use PlattensammlungWeb.ConnCase, async: false

  alias Plattensammlung.{Accounts, SoftAuthenticator}

  # Phoenix test requests go to http://www.example.com
  @origin "http://www.example.com"

  # Registers a soft passkey for a signed-in user, returns the authenticator
  defp register_passkey(conn, name \\ "Testgerät") do
    conn = get(conn, ~p"/auth/passkey/register-options")
    options = json_response(conn, 200)
    authenticator = SoftAuthenticator.new()

    params = SoftAuthenticator.register(authenticator, options, @origin) |> Map.put("name", name)
    conn = post(conn, ~p"/auth/passkey/register", params)
    assert %{"id" => _} = json_response(conn, 200)

    {conn, authenticator}
  end

  defp sign_in_with(conn, authenticator) do
    conn = get(conn, ~p"/auth/passkey/sign-in-options")
    options = json_response(conn, 200)

    post(
      conn,
      ~p"/auth/passkey/sign-in",
      SoftAuthenticator.sign_in(authenticator, options, @origin)
    )
  end

  describe "registration" do
    setup :register_and_sign_in_user

    test "stores a passkey for the signed-in user", %{conn: conn, user: user} do
      register_passkey(conn, "MacBook")

      assert [%{name: "MacBook", user_id: user_id}] = Accounts.list_passkeys!(actor: user)
      assert user_id == user.id
    end

    test "rejects an answer to a different challenge", %{conn: conn} do
      options = conn |> get(~p"/auth/passkey/register-options") |> json_response(200)

      forged =
        Map.put(options, "challenge", Base.url_encode64("not the challenge", padding: false))

      params = SoftAuthenticator.register(SoftAuthenticator.new(), forged, @origin)

      conn =
        conn
        |> get(~p"/auth/passkey/register-options")
        |> post(~p"/auth/passkey/register", params)

      assert json_response(conn, 422)
    end
  end

  test "registration needs a signed-in user", %{conn: conn} do
    assert conn |> get(~p"/auth/passkey/register-options") |> json_response(401)
  end

  describe "sign-in" do
    setup %{conn: conn} do
      %{conn: signed_in, user: user} = register_and_sign_in_user(%{conn: conn})
      {_conn, authenticator} = register_passkey(signed_in)

      # A fresh browser without session
      %{conn: build_conn(), user: user, authenticator: authenticator}
    end

    test "signs the user in", %{conn: conn, authenticator: authenticator} do
      conn = sign_in_with(conn, authenticator)
      assert %{"redirect_to" => "/"} = json_response(conn, 200)

      # The session now opens the collection instead of redirecting to sign-in
      assert conn |> get(~p"/") |> html_response(200) =~ "Sammlung"
    end

    test "records when the passkey was used", %{conn: conn, user: user, authenticator: auth} do
      sign_in_with(conn, auth)

      assert [%{last_used_at: %DateTime{}}] = Accounts.list_passkeys!(actor: user)
    end

    test "a challenge works only once", %{conn: conn, authenticator: authenticator} do
      conn = get(conn, ~p"/auth/passkey/sign-in-options")
      answer = SoftAuthenticator.sign_in(authenticator, json_response(conn, 200), @origin)

      conn = post(conn, ~p"/auth/passkey/sign-in", answer)
      assert json_response(conn, 200)

      replay = post(recycle(conn), ~p"/auth/passkey/sign-in", answer)
      assert json_response(replay, 401)
    end

    test "an unknown passkey is rejected", %{conn: conn} do
      conn = sign_in_with(conn, SoftAuthenticator.new())

      assert json_response(conn, 401)
      assert conn |> get(~p"/") |> redirected_to() == ~p"/sign-in"
    end

    test "a passkey from another site is rejected", %{conn: conn, authenticator: authenticator} do
      conn = get(conn, ~p"/auth/passkey/sign-in-options")
      options = json_response(conn, 200)
      answer = SoftAuthenticator.sign_in(authenticator, options, "https://evil.example")

      assert conn |> post(~p"/auth/passkey/sign-in", answer) |> json_response(401)
    end

    test "fails once the address is no longer allowed", %{conn: conn, authenticator: auth} do
      Application.put_env(:plattensammlung, :allowed_emails, [])

      on_exit(fn ->
        Application.put_env(:plattensammlung, :allowed_emails, ["test@example.com"])
      end)

      assert conn |> sign_in_with(auth) |> json_response(401)
    end
  end
end
