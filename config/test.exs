import Config
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :plattensammlung, Plattensammlung.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "plattensammlung_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :plattensammlung, PlattensammlungWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "bX6kqZWryCEQeNa/DMw7rR380QbsWuU9SW01j5wENuhxuO9wY3lNIlUB6C0XO+fS",
  server: false

# In test we don't send emails
config :plattensammlung, Plattensammlung.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true

# Sort query params output of verified routes for robust url comparisons
config :phoenix,
  sort_verified_routes_query_params: true

# External lookups and cover downloads hit a Req.Test stub instead of the network
config :plattensammlung,
  req_options: [plug: {Req.Test, Plattensammlung.Lookup}, retry: false],
  discogs_token: "test-token",
  covers_dir: Path.expand("../tmp/test/covers", __DIR__),
  # Tests request many links and never reach MusicBrainz: no waiting
  magic_link_limits: [per_address: {1_000, :timer.minutes(15)}, per_ip: {1_000, :timer.hours(1)}],
  musicbrainz_interval_ms: 0,
  measure_data?: false,
  cover_hosts: ["i.discogs.com", "coverartarchive.org", "archive.org", "x.test"],
  allowed_emails: ["test@example.com"],
  cleanup_covers_on_start: false,
  token_signing_secret: "s8e+mMsE8aMgXGy/5YS4X4/kvA6Yt2ou"
