defmodule PlattensammlungWeb.Router do
  use PlattensammlungWeb, :router
  use AshAuthentication.Phoenix.Router

  import AshAuthentication.Plug.Helpers

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PlattensammlungWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
    plug :load_from_session
  end

  # JSON endpoints used by the passkey JavaScript (session + CSRF like the browser)
  pipeline :passkey do
    plug :accepts, ["json"]
    plug :fetch_session
    plug :fetch_flash
    plug :protect_from_forgery
    plug :load_from_session
  end

  # API clients authenticate with `Authorization: Bearer <api key>`. Without a key
  # requests reach the API without actor and the Ash policies forbid them.
  pipeline :api do
    plug :accepts, ["json"]
    plug :load_from_bearer

    plug AshAuthentication.Strategy.ApiKey.Plug,
      resource: Plattensammlung.Accounts.User,
      required?: false

    plug :set_actor, :user
  end

  scope "/api/json" do
    pipe_through [:api]

    forward "/swaggerui", OpenApiSpex.Plug.SwaggerUI,
      path: "/api/json/open_api",
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
      on_mount: [{PlattensammlungWeb.LiveUserAuth, :live_user_required}] do
      live "/", AlbumLive.Index, :collection
      live "/wishlist", AlbumLive.Index, :wishlist
      live "/import", ImportLive
      live "/albums/new", AlbumLive.Form, :new
      live "/albums/:id", AlbumLive.Show, :show
      live "/albums/:id/edit", AlbumLive.Form, :edit
      live "/albums/:id/copies/new", CopyLive.Form, :new
      live "/copies/:id/edit", CopyLive.Form, :edit
      live "/stats", StatsLive
      live "/account", AccountLive
    end

    ash_authentication_live_session :unauthenticated,
      on_mount: [{PlattensammlungWeb.LiveUserAuth, :live_no_user}] do
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
      overrides: [PlattensammlungWeb.AuthOverrides, AshAuthentication.Phoenix.Overrides.DaisyUI]
    )
  end

  # Enable LiveDashboard and Swoosh mailbox preview in development
  if Application.compile_env(:plattensammlung, :dev_routes) do
    import Phoenix.LiveDashboard.Router

    scope "/dev" do
      # The mailbox shows magic links: never expose it to the network (LAN=1)
      pipe_through [:browser, :local_only]

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
