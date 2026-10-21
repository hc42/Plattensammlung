defmodule Plattensammlung.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      [
        PlattensammlungWeb.Telemetry,
        Plattensammlung.Repo,
        {DNSCluster, query: Application.get_env(:plattensammlung, :dns_cluster_query) || :ignore},
        {Phoenix.PubSub, name: Plattensammlung.PubSub},
        # Start a worker by calling: Plattensammlung.Worker.start_link(arg)
        # {Plattensammlung.Worker, arg},
        # Start to serve requests, typically the last entry
        PlattensammlungWeb.Endpoint,
        {AshAuthentication.Supervisor, [otp_app: :plattensammlung]}
      ] ++ cover_cleanup()

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Plattensammlung.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    PlattensammlungWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  # Removes unreferenced cover files once after start (off in tests)
  defp cover_cleanup do
    if Application.get_env(:plattensammlung, :cleanup_covers_on_start, true) do
      [
        Supervisor.child_spec({Task, &Plattensammlung.Covers.cleanup_orphans/0},
          id: :cover_cleanup
        )
      ]
    else
      []
    end
  end
end
