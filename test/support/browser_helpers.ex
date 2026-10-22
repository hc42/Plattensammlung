defmodule PlattensammlungWeb.BrowserHelpers do
  @moduledoc """
  Helpers for the browser tests (ADR 0025, `use PhoenixTest.Playwright.Case`).
  The `conn` there is a Playwright session in a real Chromium, not a Plug.Conn.
  """
  import PhoenixTest.Playwright, only: [add_session_cookie: 3, unwrap: 2]

  @doc """
  Setup: test data created in the test process (streaming link lookups when
  albums are created) never goes to the internet. The pages under test don't
  look anything up themselves.
  """
  def stub_lookups(_context) do
    Plattensammlung.LookupStub.install()
    :ok
  end

  @doc "Signs `user` in, like the session cookie of a real sign-in."
  def sign_in(conn, user) do
    {:ok, token, _claims} = AshAuthentication.Jwt.token_for_user(user)

    add_session_cookie(
      conn,
      [value: %{"user_token" => token}],
      PlattensammlungWeb.Endpoint.session_options()
    )
  end

  @doc "Moves the mouse over the first element matching `selector`."
  def hover(conn, selector) do
    unwrap(conn, fn %{frame_id: frame_id} ->
      {:ok, _} = PlaywrightEx.Frame.hover(frame_id, selector: selector, timeout: 5_000)
    end)
  end
end
