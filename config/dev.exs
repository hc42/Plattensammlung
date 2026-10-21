import Config
config :ash, policies: [show_policy_breakdowns?: true]

# Configure your database
config :plattensammlung, Plattensammlung.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "plattensammlung_dev",
  stacktrace: true,
  show_sensitive_data_on_connection_error: true,
  pool_size: 10

# For development, we disable any cache and enable
# debugging and code reloading.
#
# The watchers configuration can be used to run external
# watchers to your application. For example, we can use it
# to bundle .js and .css sources.
config :plattensammlung, PlattensammlungWeb.Endpoint,
  # Binding to loopback ipv4 address prevents access from other machines.
  # Change to `ip: {0, 0, 0, 0}` to allow access from other machines.
  http: [ip: {127, 0, 0, 1}],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "AqLmlnZbm9L8TFy7v+2aYTVbjnMzG/zX2UMh5L0iJHTTOCxfGMdXoW9aHeaxXqAH",
  watchers: [
    esbuild: {Esbuild, :install_and_run, [:plattensammlung, ~w(--sourcemap=inline --watch)]},
    tailwind: {Tailwind, :install_and_run, [:plattensammlung, ~w(--watch)]}
  ]

# ## HTTPS in the local network (camera barcode scanner on a phone)
#
# Browsers only allow camera access over HTTPS (or on localhost). To scan from a
# phone in the same Wi-Fi, create a self-signed certificate once:
#
#     mix phx.gen.cert localhost "$(scutil --get LocalHostName).local"
#
# and start the server with LAN=1. The app is then also reachable at
# https://<LocalHostName>.local:4001 from other devices. It has no login yet,
# so only do this in a trusted network.
if System.get_env("LAN") in ["1", "true"] do
  config :plattensammlung, PlattensammlungWeb.Endpoint,
    https: [
      ip: {0, 0, 0, 0},
      port: 4001,
      cipher_suite: :strong,
      keyfile: "priv/cert/selfsigned_key.pem",
      certfile: "priv/cert/selfsigned.pem"
    ]
end

# Enable dev routes for dashboard and mailbox
config :plattensammlung, dev_routes: true

# Do not include metadata nor timestamps in development logs
config :logger, :default_formatter, format: "[$level] $message\n"

# Set a higher stacktrace during development. Avoid configuring such
# in production as building large stacktraces may be expensive.
config :phoenix, :stacktrace_depth, 20

# Initialize plugs at runtime for faster development compilation
config :phoenix, :plug_init_mode, :runtime

config :phoenix_live_view,
  # Include debug annotations and locations in rendered markup.
  # Changing this configuration will require mix clean and a full recompile.
  debug_heex_annotations: true,
  debug_attributes: true,
  # Enable helpful, but potentially expensive runtime checks
  enable_expensive_runtime_checks: true

# Disable swoosh api client as it is only required for production adapters.
config :swoosh, :api_client, false
