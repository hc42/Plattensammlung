defmodule Plattensammlung.MixProject do
  use Mix.Project

  def project do
    [
      app: :plattensammlung,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      # OpenTelemetry: exporter first, and a tracing problem must not stop the app
      releases: [
        plattensammlung: [
          applications: [opentelemetry_exporter: :permanent, opentelemetry: :temporary]
        ]
      ],
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Plattensammlung.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:hammer, "~> 7.4"},
      {:peep, "~> 5.0"},
      {:opentelemetry, "~> 1.7"},
      {:opentelemetry_api, "~> 1.4"},
      {:opentelemetry_exporter, "~> 1.10"},
      {:opentelemetry_phoenix, "~> 2.0"},
      {:opentelemetry_bandit, "~> 0.3"},
      {:opentelemetry_ecto, "~> 1.2"},
      {:opentelemetry_ash, "~> 0.1"},
      {:opentelemetry_req, "~> 1.0"},
      {:picosat_elixir, "~> 0.2"},
      {:wax_, "~> 0.7"},
      {:nimble_csv, "~> 1.2"},
      {:gen_smtp, "~> 1.2"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:open_api_spex, "~> 3.0"},
      {:ash_json_api, "~> 1.0"},
      {:sourceror, "~> 1.8", only: [:dev, :test]},
      {:sobelow, "~> 0.16", only: [:dev, :test], runtime: false},
      {:ash_phoenix, "~> 2.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.6", only: [:dev, :test]},
      {:phoenix, "~> 1.8.16"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.2.0"},
      {:lazy_html, ">= 0.1.0", only: :test},
      # Browser tests (ADR 0025); the Playwright version is pinned in assets/package.json
      {:phoenix_test_playwright, "~> 0.19.0", only: :test, runtime: false},
      {:phoenix_live_dashboard, "~> 0.9.1"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.5", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:daisyui,
       github: "saadeghi/daisyui",
       tag: "v5.7.50",
       sparse: "packages/bundle",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.3.1"},
      {:bandit, "~> 1.5"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      # assets.build: the browser tests (ADR 0025) load the real JavaScript and CSS
      test: ["ash.setup --quiet", "assets.build", "test"],
      "assets.setup": [
        "tailwind.install --if-missing",
        "esbuild.install --if-missing",
        &npm_install/1
      ],
      "assets.build": ["compile", "tailwind plattensammlung", "esbuild plattensammlung"],
      "assets.deploy": [
        "tailwind plattensammlung --minify",
        "esbuild plattensammlung --minify",
        "phx.digest"
      ],
      precommit: [
        "compile --warnings-as-errors",
        "deps.unlock --unused",
        "format",
        "sobelow --config --quiet",
        "test"
      ]
    ]
  end

  # Installs the JavaScript packages in assets/ (ZXing for the barcode scanner).
  # Outside prod also Playwright with Chromium for the browser tests (ADR 0025);
  # the release image gets neither.
  defp npm_install(_args) do
    if System.find_executable("npm") == nil do
      Mix.raise("""
      npm was not found. The assets need Node.js (version in .nvmrc).
      """)
    end

    if Mix.env() == :prod do
      npm!("npm install --omit=dev")
    else
      npm!("npm install")
      npm!("npx playwright install chromium")
    end
  end

  defp npm!(command) do
    case Mix.shell().cmd(command, cd: "assets") do
      0 -> :ok
      status -> Mix.raise("#{command} failed (exit code #{status})")
    end
  end
end
