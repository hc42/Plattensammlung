# This file is responsible for configuring your application
# and its dependencies with the aid of the Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
import Config

config :mime,
  extensions: %{"json" => "application/vnd.api+json"},
  types: %{"application/vnd.api+json" => ["json"]}

config :ash_json_api,
  show_public_calculations_when_loaded?: false,
  authorize_update_destroy_with_error?: true

# These enable behaviors that will become the default in the next major
# version of Ash. Setting them now opts your application into the new
# behavior and ensures a seamless upgrade. See the backwards compatibility
# guide for an explanation of each setting:
# https://hexdocs.pm/ash/backwards-compatibility-config.html
config :ash,
  allow_forbidden_field_for_relationships_by_default: true,
  include_embedded_source_by_default?: false,
  show_keysets_for_all_actions?: false,
  default_page_type: :keyset,
  policies: [no_filter_static_forbidden_reads?: false],
  keep_read_action_loads_when_loading?: false,
  default_actions_require_atomic?: true,
  read_action_after_action_hooks_in_order?: true,
  bulk_actions_default_to_errors?: true,
  transaction_rollback_on_error?: true,
  redact_sensitive_values_in_errors?: true,
  default_string_length_count: :codepoints,
  infer_generic_action_reactors?: false,
  many_to_many_destroy_destination_on_match?: true,
  known_types: [AshPostgres.Timestamptz, AshPostgres.TimestamptzUsec]

config :spark,
  formatter: [
    remove_parens?: true,
    "Ash.Resource": [
      section_order: [
        :authentication,
        :token,
        :user_identity,
        :json_api,
        :postgres,
        :resource,
        :code_interface,
        :actions,
        :policies,
        :pub_sub,
        :preparations,
        :changes,
        :validations,
        :multitenancy,
        :attributes,
        :relationships,
        :calculations,
        :aggregates,
        :identities
      ]
    ],
    "Ash.Domain": [
      section_order: [:json_api, :resources, :policies, :authorization, :domain, :execution]
    ]
  ]

config :plattensammlung,
  ecto_repos: [Plattensammlung.Repo],
  ash_domains: [Plattensammlung.Accounts, Plattensammlung.Records],
  covers_dir: Path.expand("../uploads/covers", __DIR__),
  # Magic link requests: {count, per milliseconds} (ADR 0017)
  magic_link_limits: [per_address: {3, :timer.minutes(15)}, per_ip: {10, :timer.hours(1)}],
  # MusicBrainz allows about one request per second
  musicbrainz_interval_ms: 1_000,
  # Prometheus metrics on an own port; nil = off (METRICS_PORT, ADR 0019)
  metrics_port: nil,
  # Covers are only downloaded from these hosts (and their subdomains), see ADR 0014
  cover_hosts: ["i.discogs.com", "coverartarchive.org", "archive.org"],
  generators: [timestamp_type: :utc_datetime],
  ash_authentication: [return_error_on_invalid_magic_link_token?: true]

# Configure the endpoint
config :plattensammlung, PlattensammlungWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: PlattensammlungWeb.ErrorHTML, json: PlattensammlungWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: Plattensammlung.PubSub,
  live_view: [signing_salt: "mp57tbeQ"]

# Configure LiveView
config :phoenix_live_view,
  # the attribute set on all root tags. Used for Phoenix.LiveView.ColocatedCSS.
  root_tag_attribute: "phx-r"

# Configure the mailer
#
# By default it uses the "Local" adapter which stores the emails
# locally. You can see the emails in your browser, at "/dev/mailbox".
#
# For production it's recommended to configure a different adapter
# at the `config/runtime.exs`.
config :plattensammlung, Plattensammlung.Mailer, adapter: Swoosh.Adapters.Local

# Configure esbuild (the version is required).
# ESM with code splitting lets rarely needed libraries (e.g. ZXing for the
# barcode scanner) load on demand via import().
config :esbuild,
  version: "0.25.4",
  plattensammlung: [
    args:
      ~w(js/app.js --bundle --format=esm --splitting --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/* --alias:@=.),
    cd: Path.expand("../assets", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.3.3",
  plattensammlung: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("..", __DIR__),
    env: %{"NODE_PATH" => [Path.expand("../deps", __DIR__), Mix.Project.build_path()]}
  ]

# Configure Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Traces (ADR 0019): Ash actions as spans; exported only when runtime.exs
# configures an OTLP endpoint (OTEL_EXPORTER_OTLP_ENDPOINT)
config :ash, :tracer, [OpentelemetryAsh]
config :opentelemetry_ash, trace_types: [:custom, :action, :flow]
config :opentelemetry, traces_exporter: :none, resource: [service: [name: "plattensammlung"]]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
