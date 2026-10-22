# Security

Plattensammlung is a private application for a small, known group of people. This document
describes how to report security problems, which security model applies and which limits are
known. The reasoning is in the ADRs under [docs/adr/](docs/adr/).

## Reporting vulnerabilities

- Please do **not** report publicly (no issue, no chat), but confidentially by e-mail to
  **plattensammlung-hc@halfbrodt.org**.
- Helpful: affected page or API route, steps to reproduce, expected and actual behaviour,
  assessment of the impact.
- Don't test against other people's instances, and don't read or change other users' data to
  prove a vulnerability.

## Supported versions

There are no release branches. Security fixes go into `main` and are rolled out with a new
image (see [deploy/README.md](deploy/README.md)).

## Security model

### Sign-in ([ADR 0005](docs/adr/0005-passkey-login.md))

- Only addresses from `ALLOWED_EMAILS` can sign in. There is no open registration.
- **Passkeys** (WebAuthn) as the main way, a **magic link** by e-mail as fallback. There are
  no passwords.
- The sign-in page doesn't reveal whether an address is allowed.
- **API keys** are stored only as a hash, shown once and expire after 30 days or one year.
- Sessions live in a signed cookie (`SameSite=Lax`, `Secure` in production). AshAuthentication
  also checks that the session token exists in the database.

### Authorization ([ADR 0013](docs/adr/0013-own-collections.md), [0015](docs/adr/0015-shared-artists.md), [0016](docs/adr/0016-shared-albums.md))

- All access goes through Ash actions with policies; without signing in nothing is readable.
- Albums and artists are shared. Album data is changed by whoever has the album in collection
  or wishlist. An album is deleted only once no one has it any more. An artist can only be
  renamed or deleted while no one else has an album of theirs.
- Copies and wishes belong to one person; only they change or delete them.
- A copy's **purchase date and notes** are readable only by its owner (field policy), also
  through the API.
- Other users only see ID and display name, never the e-mail address.

### Input and output ([ADR 0006](docs/adr/0006-data-model.md), [ADR 0014](docs/adr/0014-cover-sources-and-csp.md))

- HEEx escapes all output; there is no `raw` and no `innerHTML` in JavaScript.
- All fields have type, length and value limits; barcodes are normalized and validated.
- **Covers** are only downloaded via HTTPS from known sources (Discogs, Cover Art Archive),
  also across redirects (protection against SSRF). Local cover paths are only set by the app
  itself. Uploaded images are recognized by their content (magic bytes), at most 10 MB.
- **Content Security Policy:** scripts only from the app (nonce for the inline script), images
  only from the app and the cover sources, no frames, forms only to the app.
- CSRF protection for all forms and LiveView; the API only accepts bearer keys, no session
  cookies.

### Limiting abuse ([ADR 0017](docs/adr/0017-rate-limits.md))

- Magic links: at most 3 per address in 15 minutes and 10 per IP address per hour.
- Requests to MusicBrainz are throttled to 1 per second.
- Optional `limit_req` in nginx-proxy-manager as coarse protection.

### Operations ([ADR 0011](docs/adr/0011-running-on-truenas.md), [ADR 0019](docs/adr/0019-metrics-and-traces.md))

- TLS ends at nginx-proxy-manager; the app enforces HTTPS (HSTS) via `X-Forwarded-Proto`.
- Secrets (`SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET`, database and SMTP passwords) are only in
  `app.env`/`db.env`/`grafana.env` on the NAS (`chmod 600`), never in Git or the image. The
  image contains no uploads and no certificates.
- Only port 4000 (through the proxy) is reachable from the internet. Metrics (9568), traces
  (4318), Prometheus (9090) and Grafana (3000) are meant for the LAN only.
- `/dev` (mailbox with sign-in links, LiveDashboard) only exists in development and only from
  `localhost`.
- Traces send no trace headers to Discogs, MusicBrainz or Wikidata.
- The app sends no personal data to external services; the MusicBrainz contact in the user
  agent is optional (`MUSICBRAINZ_CONTACT`).

## Known limits

- **`X-Forwarded-For`** is read without a list of trusted proxies. Whoever reaches port 4000
  directly (in the LAN) can fake their IP address and get around the per-IP limit; the
  per-address limit still applies. Port 4000 must therefore not be exposed to the internet.
- **Rate limits** are kept in memory and start over after a restart.
- **Signed-in users are trusted:** there are no rate limits for them, and whoever has an album
  can change its shared data (cover, links) for everyone.
- **Passkeys** are bound to the whole domain. If the app runs under a path of a shared domain
  ([ADR 0018](docs/adr/0018-path-prefix.md)), other apps there see the passkey in the
  selection.
- The **metrics port** has no authentication and **Grafana** only the admin password; both
  rely on the LAN. Metrics contain user IDs, but no e-mail addresses.
- The API returns `cover_url` as a path relative to the app.

## For developers

- New actions need policies; read and write data only through Ash (see [AGENTS.md](AGENTS.md)).
- New fields get length or value limits, private fields a field policy.
- Never write paths as fixed strings; image URLs only from allowed sources.
- `mix precommit` includes **Sobelow** (security scanner for Phoenix, `mix sobelow --config`).
  Any finding fails the run. Reviewed false positives are marked in the code with
  `# sobelow_skip [...]` and a reason; only the CSP and HTTPS checks are ignored globally
  (`.sobelow-conf` explains why).
- Before a release also run `mix hex.audit` (retired packages or packages with security
  advisories).

## Automated checks on GitHub

- **Dependabot** (`.github/dependabot.yml`): weekly update PRs for Elixir packages, npm
  (`assets/`), the images in the Compose files and GitHub Actions; security updates
  immediately once enabled in the repository settings. Dependabot doesn't recognize the base
  images in the `Dockerfile` (Elixir/Erlang/Debian, assembled with `ARG`); they are updated by
  hand. The CI doesn't start the Compose files: check major updates of Prometheus, Tempo or
  Grafana locally before merging.
- **CodeQL** (`.github/workflows/codeql.yml`): code scanning on every push, pull request and
  weekly. CodeQL does **not support Elixir**; it checks the JavaScript in `assets/js` and the
  workflows. Results under **Security → Code scanning**.
- **CI** (`.github/workflows/ci.yml`) on every push and pull request, including Dependabot's:
  compiling without warnings, formatting, unused packages, Ash snapshots (`ash.codegen --check`),
  Sobelow, `hex.audit` and tests against Postgres 18. Sobelow also uploads its results to code
  scanning (category `sobelow`), next to CodeQL.
