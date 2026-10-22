# Browser tests (ADR 0025): one Playwright driver for the whole run
{:ok, _} = PhoenixTest.Playwright.Supervisor.start_link()
Application.put_env(:phoenix_test, :base_url, PlattensammlungWeb.Endpoint.url())

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Plattensammlung.Repo, :manual)
