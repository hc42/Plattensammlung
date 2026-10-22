# 0011. Running on TrueNAS behind nginx-proxy-manager

- **Status:** Accepted (implemented on 2026-10-21)
- **Date:** 2026-10-21

## Context

The app is to run permanently and be reachable **publicly under an own domain**, protected by
sign-in and allow list ([ADR 0005](0005-passkey-login.md)). Available are:

- a NAS with **TrueNAS 25.10**; apps run there as Docker containers, own apps as a "custom app"
  via Compose YAML
- **nginx-proxy-manager** (NPM) as the HTTP proxy in front, handling domain, port forwarding and
  the Let's Encrypt certificate
- a mail provider with **SMTP** access

Passkeys require a valid certificate and a fixed host name. Domain and NPM provide that, the
self-signed LAN certificate from [ADR 0008](0008-https-in-the-lan.md) doesn't.

## Decision

```
Internet ──443──▶ nginx-proxy-manager ──http──▶ app:4000 ──▶ db:5432
                  (TLS, Let's Encrypt)          (Phoenix)     (Postgres 18)
```

**Image**

- An Elixir release (`mix release`) in a container, Dockerfile following
  `mix phx.gen.release --docker`. The build stage gets Node.js for `npm install` (ZXing). Built
  for **linux/amd64**.
- On start the migrations run automatically (`bin/migrate`), then `bin/server`.
- A simple health endpoint `GET /health` for the container health check.

**TrueNAS custom app (Compose)**

- Containers `app` (image from the registry) and `db` (`postgres:18`).
- ZFS datasets as host paths: `…/plattensammlung/postgres` (database) and
  `…/plattensammlung/covers` (cover images).
- Only the app port is reachable in the LAN, so NPM can reach it. Postgres stays in the app's
  internal network.

**Configuration** (the app's environment variables)

| Variable | Content |
|---|---|
| `PHX_HOST` | public domain, e.g. `platten.example.de` |
| `SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET` | random, created with `mix phx.gen.secret` |
| `DATABASE_URL` | `ecto://postgres:<pw>@db/plattensammlung` |
| `ALLOWED_EMAILS` | who may sign in |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM` | mail delivery through the own provider (Swoosh SMTP adapter) |
| `COVERS_DIR` | path of the cover volume in the container |
| `DISCOGS_TOKEN`, `MUSICBRAINZ_CONTACT` | optional |

**Changes in the code**

- In production the public address comes from `PHX_HOST` (https, port 443) instead of the
  request. That affects WebAuthn origin and RP ID, the magic link URL, absolute cover URLs in
  the JSON-LD and the server URL in OpenAPI. In development the request address stays
  (localhost, `.local`).
- Limit `check_origin` for LiveView websockets to the domain.
- Session cookie with `secure`.
- Mail delivery: `gen_smtp` as a dependency, SMTP configuration in `runtime.exs` for prod.

**nginx-proxy-manager**

- Proxy host for the domain → `http://<NAS-IP>:<app port>`, **websockets support on**, SSL with
  Let's Encrypt, "Force SSL" and HTTP/2.

**Backups**

- Daily `pg_dump` (TrueNAS cron job: `docker exec … pg_dump`) into an own dataset.
- ZFS snapshots of the datasets (database dump and covers), optionally replicated.
- In addition the CSV export from the app at any time ([ADR 0010](0010-statistics-and-export.md)).

**Delivering the image:** build locally on the Mac with Podman for amd64 (emulation), save it as
a file (`deploy/build-image.sh`), copy it to the NAS with `scp` and load it there with
`docker load`. No registry and no external account are needed. The Compose file points to
`localhost/plattensammlung:<version>` with `pull_policy: never`.

**Implementation in the repository:** `deploy/` contains the Compose file, env templates, build
and backup scripts and the guide ([deploy/README.md](../../deploy/README.md)). Secrets live in
`app.env` and `db.env` on the NAS, not in Git and not in the TrueNAS UI. The database container
only gets its own password.

## Alternatives considered

- **GitHub Actions and GitHub Container Registry**: convenient updates via `git push`, but needs
  an external account and registry credentials on the NAS.
- **VPS with Caddy**: independent of the home network, but costs monthly and needs its own
  maintenance. The NAS already exists.
- **Reachable only via VPN (Tailscale)**: more secure, but no access without a VPN client.
- **TLS directly in Phoenix**: duplicate certificate management, as NPM manages certificates
  anyway.

## Consequences

- The app is publicly reachable. Sign-in, allow list and Ash policies protect it. `/dev`
  (mailbox, dashboard) doesn't exist in prod.
- Passkeys work under the domain. Passkeys from `localhost` don't apply there; create new ones
  under the domain.
- Updates: build a new image and update the app in TrueNAS. Migrations run on start.
