# Plattensammlung

Web application for cataloguing and managing a private vinyl record collection
("Plattensammlung" is German for record collection). The interface is in English and German.

> **Status:** The roadmap is done: collection, wishlist, import, barcode scan, JSON API, sign-in with a passkey or magic link, statistics and export.

## Goals

- **Capturing with minimal effort**: only artist and album title are required, everything else is
  optional and only appears on request (⊕/⊖ like in Apple's Contacts app); genres as tags
- Scan a barcode (or search by artist and title) and take over data and cover from Discogs and MusicBrainz, without having to pick a pressing
- Answer quickly: "Do I have this record?", with links to Discogs
- **Wishlist**: remember albums you are still looking for. Scanning in a record shop immediately shows "have it" or "on the wishlist"
- Search and filter the collection, e.g. by artist, genre or year; sort by title, artist, year or
  recently added, as a cover grid or a compact list (with an A–Z bar on phones); view and order
  are remembered per browser tab, and "back" returns to the list as you left it
- **Shared catalogue, own collection per person:** every album exists once, each person has
  their own copies and their own wishlist, visible to the others (page "Collectors", "Also with …" on
  the album page). Everyone who has an album maintains its data; it is deleted only once no one
  has it any more. Purchase date and notes stay private, also in the API
- Access through a web interface **and** a JSON API
- Sign-in with passkeys; users can delete their own account
- **All albums**: the shared catalogue, filterable to "Not mine"
- **Merging duplicates**: two entries of the same record become one, with everyone's copies and wishes
- **Matching** existing albums with Discogs/MusicBrainz, also by scanning a barcode later; pressing details go into the copy
- **Spotify and Tidal**: links are found automatically (Wikidata, MusicBrainz) or pasted;
  albums can also be added from a Spotify link or its QR code
- **Covers**: upload (also with the phone camera), replace or remove; orphaned image files are cleaned up
- **On the phone**: tab bar at the bottom with a large scan button that opens the camera directly;
  installable on the home screen as an app with a "Scan" shortcut
  ([ADR 0022](docs/adr/0022-installable-app.md))
- **Look and feel**: records slide out of their sleeves, albums without a cover get a label in
  their own colour, the page background takes on the colour of the album under the mouse, the
  cover morphs into the album page, which is tinted in the cover's colour and shows the record
  with its label
- **English and German**: follows the browser language, can be fixed on the account page
  ([ADR 0021](docs/adr/0021-internationalization.md))
- Statistics (size, genres, decades, condition) and export as CSV or JSON-LD (schema.org)
- **Security:** covers only from Discogs and the Cover Art Archive (or uploaded),
  Content Security Policy on all pages ([ADR 0014](docs/adr/0014-cover-sources-and-csp.md)),
  rate-limited magic links and throttled MusicBrainz requests ([ADR 0017](docs/adr/0017-rate-limits.md));
  see [SECURITY.md](SECURITY.md)

## Technology

| Area | Choice | Decision |
|---|---|---|
| Language / web | Elixir, Phoenix | [ADR 0002](docs/adr/0002-elixir-phoenix-ash.md) |
| Application framework | Ash (AshPostgres, AshPhoenix) | [ADR 0002](docs/adr/0002-elixir-phoenix-ash.md) |
| Database | PostgreSQL in Podman (Compose) | [ADR 0003](docs/adr/0003-postgresql-with-podman.md) |
| Interfaces | Phoenix LiveView and AshJsonApi | [ADR 0004](docs/adr/0004-liveview-and-json-api.md) |
| Sign-in | AshAuthentication, passkeys via `wax_`, magic link as fallback | [ADR 0005](docs/adr/0005-passkey-login.md) |
| Import | Barcode scan in the browser, Discogs API, MusicBrainz and Cover Art Archive | [ADR 0007](docs/adr/0007-barcode-scan-and-import.md) |
| Operations | Container on TrueNAS behind nginx-proxy-manager | [ADR 0011](docs/adr/0011-running-on-truenas.md) |
| Observability | Prometheus metrics, OpenTelemetry traces to Tempo, Grafana | [ADR 0019](docs/adr/0019-metrics-and-traces.md) |
| Languages | Gettext, English default, German translation | [ADR 0021](docs/adr/0021-internationalization.md) |

## Data model

```
Artist ──< Album ──< Copy  >── User
                 └──< Wish  >── User
```

- **Album**: the work, independent of the pressing (required: title and artist; optional: year, cover, genres, links).
  Corresponds to the *release group* on MusicBrainz and the *master* on Discogs.
- **Copy**: one person's copy. An album with an own copy = "I have it". All pressing and collector details are optional (label, barcode, condition, purchase date, notes).
- **Wish**: "I'm looking for it", an entry on one person's wishlist.
- Artists and albums are shared by everyone ([ADR 0015](docs/adr/0015-shared-artists.md), [ADR 0016](docs/adr/0016-shared-albums.md)).

Details in [ADR 0006](docs/adr/0006-data-model.md).

## Roadmap

1. ✅ Create the project (Phoenix and Ash via Igniter), Postgres via `compose.yml`
2. ✅ Domain `Records` with artist, album and copy, plus seed data
3. ✅ LiveView interface: list, search and filters, detail page, quick capture, wishlist
4. ✅ Import: search by artist and title and by barcode on Discogs and MusicBrainz, store covers locally
5. ✅ Barcode scan with the camera in the browser (HTTPS in the LAN: [ADR 0008](docs/adr/0008-https-in-the-lan.md))
6. ✅ JSON API (AshJsonApi) with OpenAPI docs ([ADR 0009](docs/adr/0009-json-api-design.md))
7. ✅ Sign-in with passkeys, magic link as fallback, API keys ([ADR 0005](docs/adr/0005-passkey-login.md))
8. ✅ Statistics and export as CSV and JSON-LD ([ADR 0010](docs/adr/0010-statistics-and-export.md))
9. ✅ Running on the NAS (TrueNAS, nginx-proxy-manager, SMTP): guide in [deploy/README.md](deploy/README.md), [ADR 0011](docs/adr/0011-running-on-truenas.md)

## Development

Requirements: Elixir 1.20 / OTP 29, Node.js 24 (for the scanner library, version in `.nvmrc`)
and Podman (with a running `podman machine`).

```bash
podman compose up -d   # start Postgres 18 in a container (port 5432, localhost only)
mix setup              # dependencies, create and migrate the database, assets, seeds
mix phx.server         # start the app: http://localhost:4000
```

Environment variables (set before `mix phx.server`):

| Variable | Purpose |
|---|---|
| `ALLOWED_EMAILS` | **Required.** Comma-separated e-mail addresses that may sign in |
| `DISCOGS_TOKEN` | Personal token from https://www.discogs.com/settings/developers. Without it only MusicBrainz is searched. |
| `MUSICBRAINZ_CONTACT` | E-mail address or URL that MusicBrainz asks for in the user agent |
| `COVERS_DIR` | Where downloaded covers are stored (default: `uploads/covers`, not in Git) |

```bash
export ALLOWED_EMAILS=you@example.com DISCOGS_TOKEN=your-token
```

### Signing in

1. Open http://localhost:4000, enter your e-mail address and choose "Send sign-in link".
2. In development the e-mail lands in the mailbox at http://localhost:4000/dev/mailbox.
   Open the link there and click "Jetzt anmelden" (sign in now).
3. Add a passkey under "Konto" (account, person icon). From then on you sign in with
   fingerprint or Face ID.

A passkey only works for the address it was created on (`localhost` or `<name>.local`).

### Scanning from a phone

The live camera needs HTTPS. Create a certificate once:

```bash
mix phx.gen.cert localhost "$(scutil --get LocalHostName).local"
```

Then start the server with `LAN=1`:

```bash
LAN=1 mix phx.server
```

On the phone (same Wi-Fi) open `https://<LocalHostName>.local:4001/import` and accept the
certificate warning once. `scutil --get LocalHostName` shows the name. Without HTTPS, taking a
photo ("Foto aufnehmen") still works. Only use this in a trusted network.

### Metrics and traces locally

The development server serves metrics at http://localhost:9568/metrics. Prometheus, Tempo
and Grafana run in Podman on request (Compose profile, same configuration and dashboards as on
the NAS):

```bash
podman compose --profile observability up -d
OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 mix phx.server
```

Grafana: http://localhost:3000 (no sign-in), dashboards "Plattensammlung" and "Plattensammlung –
Traces", traces under "Explore → Tempo". Prometheus: http://localhost:9090. Without the
variable the app sends no traces. Stop: `podman compose --profile observability down`.

More commands:

```bash
mix test               # tests (creates the test database automatically)
mix precommit          # compile with warnings as errors, format, Sobelow, tests
podman compose down    # stop Postgres (data stays in the volume)
```

## JSON API

JSON:API at `/api/json`, interactive docs in the Swagger UI at
http://localhost:4000/api/json/swaggerui (specification: `/api/json/open_api`).

```bash
curl -H "Authorization: Bearer $API_KEY" -H "Accept: application/vnd.api+json" "http://localhost:4000/api/json/albums?query=beatles&include=artist"
```

`order=title|artist|year|added` chooses the order of `GET /albums` (`added`: newest first); the
JSON:API `sort` parameter works as well.

```bash
curl -X POST http://localhost:4000/api/json/albums/collection -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/vnd.api+json" -d '{"data":{"artist_name":"Kraftwerk","title":"Autobahn","copy":{"format":["LP"]}}}'
```

Adding (`/albums/collection`, `/albums/wishlist`) and removing (`DELETE /albums/:id/mine`) are
generic routes: the arguments sit directly under `data`, the answer is the album as plain JSON.
An album that already exists is reused.

Every request needs an API key (page "Konto"): `-H "Authorization: Bearer <key>"`.
Without a key the API answers 403. The Swagger UI can be read without a key; for "Try it out"
enter the key under "Authorize".

## Operations

The app runs as a container on a TrueNAS NAS behind nginx-proxy-manager, either on its own
domain or under a path such as `cloud.example.com/plattensammlung` (`PHX_PATH`,
[ADR 0018](docs/adr/0018-path-prefix.md)). Metrics for Prometheus and traces for Tempo, with
Grafana dashboards and alerts: `deploy/observability/` ([ADR 0019](docs/adr/0019-metrics-and-traces.md)).
Building the image, configuration, backups and updates: [deploy/README.md](deploy/README.md).

## Documentation

- [AGENTS.md](AGENTS.md): notes for AI assistants and contributors
- [SECURITY.md](SECURITY.md): security model, known limits, reporting vulnerabilities
- [docs/adr/](docs/adr/): architecture decision records

## License

[MIT](LICENSE). The libraries used have their own licenses (among them MIT and Apache 2.0),
see `deps/` and `assets/node_modules/`. Data and covers from Discogs, MusicBrainz, Wikidata and
the Cover Art Archive are subject to their terms of use.
