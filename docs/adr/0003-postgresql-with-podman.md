# 0003. PostgreSQL in Podman via Compose

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

Ash needs a data layer. The development machine (macOS) has no local Postgres, but Podman and
Apple Container.

## Decision

- **PostgreSQL** with **AshPostgres** as the data layer.
- Postgres runs as a container with **Podman**, controlled by a `compose.yml` in the project
  (`podman compose up -d`). The data is in a named volume.
- During development the Phoenix app runs directly on the Mac, so compiling and live reload
  stay fast.

## Alternatives considered

- **SQLite (AshSqlite)**: nothing to install, but fewer features (aggregates, full-text and
  trigram search, migrations).
- **DuckDB**: built for analytics (OLAP), not for an app with many individual writes. There is
  no Ash data layer.
- **Apple Container**: works, but is still young and has no Compose support.

## Consequences

- The full Ash feature set, e.g. fuzzy search with `pg_trgm` and aggregates in the database.
- The container must be running before developing.
