# 0004. LiveView interface and JSON API

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

The collection is to be used in the browser. At the same time both approaches are to be
learned: server-side UI and API.

## Decision

- **Phoenix LiveView** as the web interface, forms via `AshPhoenix.Form`.
- **AshJsonApi** as a JSON:API interface with generated OpenAPI docs (Swagger UI).
- Both use the same Ash actions, so the logic exists only once.

## Alternatives considered

- **Only LiveView** or **only an API**: would be simpler, but misses the learning goal.
- **AshGraphql** instead of AshJsonApi: possible, can be added later.

## Consequences

- Actions must be designed to work equally well for UI and API.
- The API needs its own authentication (tokens), see ADR 0005.
