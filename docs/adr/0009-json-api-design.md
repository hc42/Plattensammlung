# 0009. Design of the JSON API

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

[ADR 0004](0004-liveview-and-json-api.md) states that next to the LiveView interface there is a
JSON API with AshJsonApi and OpenAPI docs. Open was what the endpoints look like and how they
relate to the existing Ash actions.

## Decision

- **Format:** JSON:API (`application/vnd.api+json`) via AshJsonApi 1.x, mounted at `/api/json`.
  OpenAPI specification at `/api/json/open_api`, Swagger UI at `/api/json/swaggerui`.
- **Routes** are declared in the domain `Plattensammlung.Records` (`json_api do routes`). Every
  route calls an existing action, there is no API-specific logic:

  | Method and path | Action |
  |---|---|
  | `GET /albums?query=…&status=collection\|wishlist` | `Album.search` |
  | `GET /albums/lookup?query=…` | `Album.lookup` (generic action, returns a plain JSON array) |
  | `POST /albums/collection`, `POST /albums/wishlist` | `add_to_collection`, `add_to_wishlist` |
  | `PATCH /albums/:id/wanted`, `/unwanted` | `mark_wanted`, `unmark_wanted` |
  | `GET/PATCH/DELETE /albums/:id`, `GET /albums/:id/copies` | standard actions, relationship |
  | `POST/GET/PATCH/DELETE /copies…`, `…/artists…` | standard actions |

- Relationships can be included with `?include=artist,copies`.
- Aggregates and calculations (`owned`, `copy_count`, `discogs_url`) are in `default_fields` and
  so part of every response.
- Cover URLs are relative (`/covers/…`) as long as they are stored locally.
- **No authentication** until the sign-in is implemented ([ADR 0005](0005-passkey-login.md)).
  The bearer auth that AshJsonApi writes into the OpenAPI specification by default is removed
  until then.

## Alternatives considered

- **Own Phoenix controllers with plain JSON**: freer in format, but every route would have to be
  written, validated and documented by hand.
- **AshGraphql**: more flexible for clients, but more than needed for a learning and collection
  app. Can be added later.

## Consequences

- New actions become API endpoints with one line in `routes`. The OpenAPI docs are generated.
- AshJsonApi runs PATCH routes as an atomic update first. AshPostgres can't load aggregates
  then, so `mark_wanted`/`unmark_wanted` are deliberately not atomic (change as a function).
- Without sign-in the API is writable in the whole Wi-Fi with `LAN=1`
  ([ADR 0008](0008-https-in-the-lan.md)).

## Addendum (2026-10-21)

Authentication is implemented: API keys via `Authorization: Bearer …`, see
[ADR 0005](0005-passkey-login.md). Without a key the API answers 403. The OpenAPI specification
and the Swagger UI stay readable without a key. The specification describes a bearer scheme
again, so "Authorize" in the Swagger UI sends the API key along.

## Addendum (2026-10-22): order of the album list

`GET /albums` accepts `order=title|artist|year|added` (`added`: newest first, by when the user
added a copy or wish). The argument of `Album.search` is deliberately not called `sort`: that is
the JSON:API sort parameter of index routes, which keeps working (`?sort=-year`).
