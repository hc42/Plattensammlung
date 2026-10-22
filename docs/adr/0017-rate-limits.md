# 0017. Rate limits

- **Status:** Accepted
- **Date:** 2026-10-22

## Context

In production the app is reachable from the internet. So far there were no rate limits:

- "Anmeldelink senden" (send sign-in link) is reachable without signing in. Submitted in a
  loop, it floods the mailbox of an allowed address and can get the SMTP access throttled or
  blocked by the mail provider.
- MusicBrainz allows about one request per second per IP address; one import search triggers
  several requests in quick succession. The app only retried on 503.
- Behind nginx-proxy-manager the app only saw the proxy as the sender.

Signed-in users are trusted (allow list); their pages and the API need no limits. Passkeys and
API keys are cryptographically safe against guessing.

## Decision

- **The Hammer library** with the ETS backend (`Plattensammlung.RateLimit`): in memory, no
  further service. The counters start over after a restart.
- **Magic links** (`Accounts.RequestMagicLink`, replaces the `run` of the action
  `request_magic_link`): at most 3 per address in 15 minutes and 10 per IP address per hour
  (`config :plattensammlung, :magic_link_limits`). Beyond that nothing is sent, the answer stays
  the same. The IP address comes from the sign-in page through the action context
  (`client_ip`).
- **Client IP** (`PlattensammlungWeb.ClientIp`): prefers `X-Forwarded-For`, namely its last
  entry (the proxy appends it itself; earlier entries come from the client), otherwise the
  address of the connection. As a plug in the endpoint (`conn.remote_ip`), for LiveViews via
  `connect_info` (`:peer_data`, `:x_headers`).
- **MusicBrainz** (`Lookup.Throttle`): all of the app's requests keep at least 1 second apart
  (`:musicbrainz_interval_ms`). A Req request step waits for its time slot; the GenServer only
  hands out slots, waiting happens in the calling process.
- **Proxy:** an optional `limit_req` snippet for nginx-proxy-manager is in `deploy/README.md`
  (10 requests per second per IP, bursts up to 50).

## Alternatives considered

- **`X-Forwarded-For` only from known proxy addresses** (`TRUSTED_PROXIES`): safer against
  faked headers, but more configuration. As port 4000 is only reachable in the LAN, the last
  entry is enough.
- **Limits only in the proxy:** NPM doesn't know what requests mean (a magic link is just a
  websocket message over the LiveView connection).
- **Rate limits for signed-in users and the API:** not needed, they are trusted.

## Consequences

- An import search with MusicBrainz takes a few seconds longer, but stays within the rules.
- Whoever reaches port 4000 directly can fake `X-Forwarded-For` and so get around the per-IP
  limit; the per-address limit still applies.
- Several app instances would have separate counters and throttles (currently there is one).
- Tests set high limits and no MusicBrainz gap (`config/test.exs`).
