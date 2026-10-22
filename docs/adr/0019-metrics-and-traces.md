# 0019. Metrics (Prometheus) and traces (OpenTelemetry)

- **Status:** Accepted
- **Date:** 2026-10-22

## Context

In production there was no insight at all: how many requests to which pages, how fast, who uses
how much, successful and failed sign-ins, data volume, behaviour of the external services.
Phoenix only came with metric definitions for the LiveDashboard in development. Events
(individual occurrences with context) and logs follow later.

## Decision

- **Metrics via `:telemetry`** (Phoenix, LiveView, Ash, Ecto, Finch for Req and own events),
  collected with **Peep**, as Prometheus text at `/metrics` on an **own port** (`METRICS_PORT`,
  9568 on the NAS). Not through the app endpoint, so the port is only reachable in the LAN and
  never goes through nginx-proxy-manager. Without `METRICS_PORT` there is no endpoint.
- **Metrics** (`Plattensammlung.Metrics`):
  - HTTP: count by route pattern (`/albums/:id`), method, status and kind of client (browser
    session, API key, anonymous); duration by route.
  - LiveView: mounts by view, events by view and event with duration.
  - Per user: HTTP requests and LiveView events (user ID; few users).
  - Ash actions by domain, resource and action, with duration (covers interface and API).
  - Sign-ins by method (passkey, magic link, API key) and result; magic link requests accepted
    or rejected by the rate limit.
  - Data volume every minute: albums, copies, wishes, artists, users, number and size of cover
    files, size of the database.
  - External services by host and status with duration, waiting time of the MusicBrainz throttle.
  - System: memory, run queue, database queries by table.
  - **Not per IP address:** every address would be a new time series. That belongs in logs.
- **Traces with OpenTelemetry:** `opentelemetry_bandit` and `opentelemetry_phoenix` (requests,
  LiveView), `opentelemetry_ecto` (queries), `opentelemetry_ash` (actions, as Ash tracer) and
  `opentelemetry_req` (external requests, without trace headers to third parties). Export via
  OTLP/HTTP only with `OTEL_EXPORTER_OTLP_ENDPOINT`, otherwise `traces_exporter: :none`. In the
  release `opentelemetry` starts as `:temporary`, so a tracing problem doesn't stop the app.
- **On the NAS:** Prometheus, Tempo and Grafana as their own TrueNAS app
  (`deploy/observability/`), Grafana with prepared data sources and dashboard.

## Alternatives considered

- **Metrics via OpenTelemetry:** still experimental in Erlang/Elixir; Prometheus via
  `telemetry_metrics` is proven.
- **PromEx:** many ready-made dashboards, but considerably more dependencies and configuration.
- **LiveDashboard in production:** only live values without history, would need an admin role.
- **`/metrics` on the app endpoint with a token:** would be reachable from the internet through
  the proxy.

## Consequences

- New pages, actions and external calls appear in metrics and traces without further work. New
  own events: define and emit them in `Plattensammlung.Metrics`.
- Avoid high cardinality: tags only with few possible values (no paths, album IDs, IP addresses).
- Asynchronous LiveView work (`start_async`, e.g. the import) appears as its own trace without a
  link to the triggering event.
- Counters start at zero after every restart; Prometheus accounts for that in `rate` and
  `increase`.

## Addendum (2026-10-22): alerts and traces dashboard

- **Alerts with Grafana Alerting**, as files in the repo
  (`deploy/observability/grafana/provisioning/alerting/`), the same locally and on the NAS.
  Notification by e-mail through the app's SMTP access (`grafana.env`, `ALERT_EMAIL`). Rules with
  starting values: app unreachable (5 min), more than 5 requests/s (10 min), more than 1 anonymous
  request/s (10 min), more than 10 failed sign-ins per hour, rate-limited magic links, more than
  5 % server errors (10 min), p95 above 2 s excluding import and matching (15 min), more than
  20 % errors at an external service (15 min). Only "app unreachable" treats missing data as an
  alert.
- **Counters start at 0:** Prometheus only recognizes an increase once the time series exists.
  The sign-in counters are therefore sums created with 0 for all combinations at start
  (`Metrics.init_counters/0`); otherwise the alert for failed sign-ins would never have fired
  (reproduced in a test).
- **Tempo metrics generator:** span metrics and service graph (app, database, external services)
  from the traces, written to Prometheus via remote write. Dashboard "Plattensammlung – Traces"
  with service graph, figures per span and TraceQL lists (slow requests, errors, slow external
  requests, Ash actions, database queries). Tempo doesn't know `span:parent` (checked up to 3.1);
  root spans are found with `nestedSetParent < 0`.

## Addendum (2026-10-22): storage

- Traces stay 14 days in Tempo, estimated at about 100 MB.
- Prometheus on the NAS: 90 days **or** 2 GB, whichever comes first
  (`--storage.tsdb.retention.size`), scraping every 30 instead of 15 seconds. Locally 7 days or
  500 MB.
- The minute data measurement no longer creates traces (non-sampled parent span in
  `Metrics.measure_data/0`); without any use it was the largest source of spans. Its metrics stay.

## Addendum (2026-10-22): Tempo 3

Dependabot updated Tempo from 2.8 to 3.1. Tempo 3 rejects the `compactor` section; compaction and
retention moved to `backend_scheduler.provider.compaction.compaction.block_retention` and
`backend_worker.compaction.block_retention` (both set to 336 h, which is also the default). The CI
doesn't start the observability stack, so such major updates must be checked locally before
merging.
