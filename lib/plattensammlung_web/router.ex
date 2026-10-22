defmodule PlattensammlungWeb.Router do
  use PlattensammlungWeb, :router

  # Browser tests (ADR 0025): LiveViews join the test's Ecto sandbox before
  # AshAuthentication loads the user. Empty outside the test env
  @sandbox_hooks if Application.compile_env(:plattensammlung, :sql_sandbox, false),
                   do: [PlattensammlungWeb.LiveSandbox],
                   else: []
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlattensammlungWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug PlattensammlungWeb.Plugs.ContentSecurityPolicy
    plug :load_from_session
    # After load_from_session: the user's language choice wins over the browser's
    plug PlattensammlungWeb.Locale
  end

  # Development tools (LiveDashboard, mailbox preview) bring inline scripts and
  # styles, so they get the browser pipeline without the CSP
  pipeline :dev_browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  # JSON endpoints used by the passkey JavaScript (session + CSRF like the browser)
  pipeline :passkey do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :load_from_session
    # Error texts in the sign-in language
    plug PlattensammlungWeb.Locale
  end

  # API clients authenticate with `Authorization: Bearer <api key>`. Without a key
  # requests reach the API without actor and the Ash policies forbid them.
  pipeline :api do
    plug :accepts, ["json"]
    plug :count_api_key_sign_in
    plug :load_from_bearer

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Plattensammlung.Accounts.User,
      required?: false

    plug :set_actor, :user
  end

  # Metrics (ADR 0019): was the API key valid? Known only once the response goes out
  defp count_api_key_sign_in(conn, _opts) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> _] ->
        register_before_send(conn, fn conn ->
          result = if conn.assigns[:current_user], do: :success, else: :failure
          Plattensammlung.Metrics.sign_in(:api_key, result)
          conn
        end)

      _ ->
        conn
    end
  end

  # Container health check (TrueNAS): app and database reachable
  scope "/", PlattensammlungWeb do
    get "/health", HealthController, :show
    # Web app manifest (ADR 0022), public like the icons it names
    get "/manifest.webmanifest", ManifestController, :show
  end

  scope "/api/json" do
    pipe_through [:api]

    forward "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      # Relative, so it also works under a path prefix (ADR 0018)
      path: "open_api",
      default_model_expand_depth: 4

    forward "/", PlattensammlungWeb.AshJsonApiRouter
  end

  scope "/auth/passkey", PlattensammlungWeb do
    pipe_through :passkey

    get "/sign-in-options", PasskeyController, :sign_in_options
    post "/sign-in", PasskeyController, :sign_in
    get "/register-options", PasskeyController, :register_options
    post "/register", PasskeyController, :register
  end

  scope "/", PlattensammlungWeb do
    pipe_through :browser

    ash_authentication_live_session :authenticated,
      on_mount_prepend: @sandbox_hooks,
      on_mount: [
        {PlattensammlungWeb.LiveUserAuth, :live_user_required},
        {PlattensammlungWeb.Locale, :default},
        {PlattensammlungWeb.Nav, :default}
      ] do
      live "/", AlbumLive.Index, :collection
      live "/wishlist", AlbumLive.Index, :wishlist
      live "/import", ImportLive
      live "/albums", AlbumLive.Index, :all
      live "/albums/new", AlbumLive.Form, :new
      live "/albums/:id", AlbumLive.Show, :show
      live "/albums/:id/edit", AlbumLive.Form, :edit
      live "/albums/:id/match", AlbumLive.Match
      live "/albums/:id/merge", AlbumLive.Merge
      live "/albums/:id/copies/new", CopyLive.Form, :new
      live "/copies/:id/edit", CopyLive.Form, :edit
      live "/stats", StatsLive
      live "/collectors", CollectorsLive
      live "/collectors/:user_id", AlbumLive.Index, :user_collection
      live "/collectors/:user_id/wishlist", AlbumLive.Index, :user_wishlist
      live "/account", AccountLive
    end

    ash_authentication_live_session :unauthenticated,
      on_mount_prepend: @sandbox_hooks,
      on_mount: [
        {PlattensammlungWeb.LiveUserAuth, :live_no_user},
        {PlattensammlungWeb.Locale, :default}
      ] do
      live "/sign-in", SignInLive
    end

    get "/export/plattensammlung.csv", ExportController, :csv
    get "/export/plattensammlung.jsonld", ExportController, :json_ld

    # Magic link callback (/auth/user/magic_link) and sign out
    auth_routes AuthController, Plattensammlung.Accounts.User, path: "/auth"
    sign_out_route AuthController, "/sign-out"

    # The link in the e-mail opens this page; a click on the button signs in
    magic_sign_in_route(Plattensammlung.Accounts.User, :magic_link,
      auth_routes_prefix: "/auth",
      overrides: [PlattensammlungWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.DaisyUI],
      on_mount: [{PlattensammlungWeb.Locale, :default}],
      # The override texts below are msgids in priv/gettext/*/auth.po
      gettext_backend: {PlattensammlungWeb.Gettext, "auth"}
    )
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:plattensammlung, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      # The mailbox shows magic links: never expose it to the network (LAN=1)
      pipe_through [:dev_browser, :local_only]

      live_dashboard "/dashboard", metrics: PlattensammlungWeb.Telemetry
      forward "/mailbox", Plug.Swoosh.MailboxPreview
    end

    defp local_only(conn, _opts) do
      case conn.remote_ip do
        {127, 0, 0, 1} -> conn
        {0, 0, 0, 0, 0, 0, 0, 1} -> conn
        _ -> conn |> send_resp(:forbidden, "Only available on this computer") |> halt()
      end
    end
  end
end
