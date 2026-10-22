# 0018. Optional path prefix

- **Status:** Accepted
- **Date:** 2026-10-22

## Context

Optionally, the app is to run under a path of a shared domain, e.g.
`https://cloud.example.com/plattensammlung`, instead of its own (sub)domain. Without
configuration everything is to run under `/` as before.

## Decision

- **The proxy strips the prefix** (nginx `location /plattensammlung/ { proxy_pass
  http://app/; }`). The app itself keeps serving everything under `/`: router, static files,
  covers and the LiveView socket stay unchanged.
- **The app knows the prefix** through the optional environment variable `PHX_PATH`
  (`runtime.exs` → the endpoint's `url: [path: …]`) and puts it in front of every link it
  generates:
  - Verified routes (`~p`) and static paths take it automatically.
  - JavaScript reads it from `<meta name="base-path">` (`assets/js/app_path.js`): LiveView socket
    and passkey requests.
  - Local covers (`/covers/…` in the database) get it when displayed (`Endpoint.path/1`); they
    are still stored without the prefix.
  - Absolute URLs: `PublicUrl.base_url/1` stays scheme + host (for the WebAuthn origin and `~p`
    links in e-mails), `PublicUrl.url/2` adds the prefix (JSON-LD, OpenAPI server).
  - The Swagger UI loads the specification via a relative path.

## Alternatives considered

- **The app strips the prefix itself:** Phoenix dispatches the LiveView socket before any own
  plugs, and `socket "/live"` is fixed at compile time. The prefix would no longer be
  configurable at runtime.
- **Build the prefix into router and assets:** then the app would only run under this path,
  also in development.

## Consequences

- With a prefix, nginx-proxy-manager needs its own `location` with websocket headers (guide in
  `deploy/README.md`).
- New paths in JavaScript always via `appPath()`, new absolute URLs via `PublicUrl.url/2`; never
  write `/…` as a fixed string in JS or strings.
- The API keeps returning `cover_url` without the prefix (`/covers/…`, relative to the app).
- Passkeys are bound to the whole domain, not just the path.
