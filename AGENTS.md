# AGENTS.md

Notes for AI assistants (Claude Code, Codex, etc.) and contributors to this project.

## Project

Web application for managing a private vinyl record collection with Elixir, Phoenix and the
Ash Framework. Overview and roadmap are in the [README.md](README.md), the reasons behind
decisions in [docs/adr/](docs/adr/).

## Working together

- The owner is learning Ash and Phoenix with this project. Briefly explain steps and Ash
  concepts when they are new, e.g. resources, actions, relationships, calculations,
  aggregates and policies.
- The user interface is in English (default) and German, see "Languages" below.
- Talk to the owner in **German**. Code, identifiers, commit messages and **all documentation**
  (README, AGENTS.md, SECURITY.md, ADRs, deploy guide, comments) are in **English**.
- Plan and discuss first, then build. Agree on larger design decisions beforehand.

## Keeping the documentation current (mandatory)

Update these documents **without being asked** as soon as something changes:

- **README.md**: status, features, technology, roadmap, development commands.
- **SECURITY.md**: security model and known limits, on every change to sign-in,
  authorization, input validation, rate limits or open ports.
- **AGENTS.md**: conventions, commands, project structure and pitfalls.
- **docs/adr/**: every architecturally relevant decision (technology, data model,
  authentication, interfaces, deployment) gets a new ADR. Use the template
  [docs/adr/template.md](docs/adr/template.md) and number consecutively
  (`NNNN-short-title.md`). Don't rewrite existing ADRs: when a decision changes, add a new
  ADR and set the old one to "Superseded by ADR NNNN". Status updates are allowed
  (Proposed → Accepted), as are addenda and the open questions of a "Proposed" ADR.
- Keep the index in [docs/adr/README.md](docs/adr/README.md) current.

## Technology and conventions

- Elixir 1.20 / OTP 29, Phoenix 1.8, Ash 3.x, PostgreSQL 18 (`min_pg_version` in the repo)
- Create and extend the project with Igniter (`mix igniter.install …`) where possible instead
  of writing configuration by hand.
- Data access **only through Ash**: the domains' code interfaces (`define`) instead of direct
  `Ecto.Repo` access.
- Generate migrations with `mix ash.codegen <name>`, don't write them by hand (data steps may
  be added to a generated migration).
- Business logic belongs in Ash actions, changes and validations, not in LiveViews or
  controllers.
- Domains: `Plattensammlung.Records` (records), `Plattensammlung.Accounts` (users and sign-in).
- Postgres runs in Podman (`compose.yml`), the Phoenix app locally on the Mac.

## Commands

- `podman compose up -d`: start Postgres (needed before anything else)
- `podman compose --profile observability up -d`: Prometheus, Tempo, Grafana locally
  (http://localhost:3000); traces with `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4318 mix phx.server`
- `mix setup`: dependencies, database, assets, seeds
- `mix phx.server`: development server at http://localhost:4000
- `mix test`: tests, including the browser tests in a real Chromium (builds the assets first;
  `mix setup` installs Chromium, ADR 0025). Screenshots and traces go to `tmp/`
- `mix precommit`: **run before every commit** and fix all problems (includes Sobelow)
- `mix sobelow --config`: security scan; mark reviewed false positives with
  `# sobelow_skip ["Check"]` and a reason directly above the function, don't ignore globally
- `mix ash.codegen <name>`: generate migrations from Ash resources, then `mix ash.migrate`
- `mix gettext.extract --merge`: collect new interface texts into `priv/gettext/`, then add the
  German translations in `priv/gettext/de/LC_MESSAGES/default.po`
- `mix ash.reset`: rebuild the development database, then `mix run priv/repo/seeds.exs`

## Project structure

- `lib/plattensammlung/`: business logic (Ash domains and resources, `Repo`)
- `lib/plattensammlung_web/`: Phoenix (router, LiveViews, components)
  - `live/album_live/`: `Index` (collection `/`, wishlist `/wishlist`, catalogue `/albums`,
    search via `?q=`), `Show` (`/albums/:id`), `Form` (quick capture `/albums/new`, edit
    `/albums/:id/edit`), `Match` (`/albums/:id/match`), `Merge` (`/albums/:id/merge`)
  - `live/copy_live/form.ex`: add a copy (`/albums/:id/copies/new`) and edit it (`/copies/:id/edit`)
  - `live/sign_in_live.ex` (`/sign-in`), `live/account_live.ex` (`/account`: display name, language, passkeys, API keys)
  - `controllers/passkey_controller.ex`, `controllers/auth_controller.ex`: sign-in
  - `live/stats_live.ex` (`/stats`), `controllers/export_controller.ex`: statistics and export
  - `live/import_live.ex`: import page `/import` (barcode or text, take over a result with a click)
  - `live/collectors_live.ex`: other users' collections and wishlists (`/collectors`)
  - `ash_json_api_router.ex`: JSON:API at `/api/json`, Swagger UI at `/api/json/swaggerui`
  - `components/album_components.ex`: `cover` (placeholder with initials; `morph` for the view
    transition), `sleeve` (cover with the record sliding out in the grid), `record` (the record
    with its label on the album page), `label_style/1` (label colour per album), `back_link`,
    `local_cover_path/1`, `status_badge`, condition helpers, `format_date`,
    `user_name`, `field_label` (imported in all views)
  - `locale.ex`: language of a request and of LiveViews (plug and `on_mount`, ADR 0021)
  - `controllers/manifest_controller.ex`: web app manifest (`/manifest.webmanifest`, ADR 0022);
    service worker `priv/static/sw.js` (offline page only) and `priv/static/offline.html`;
    app icons from `priv/static/images/icon.svg` (PNGs rendered with `rsvg-convert`)
  - `nav.ex`: `on_mount` hook for `@current_path`; `components/layouts.ex`: top navigation
    (desktop) and bottom tab bar with the scan button (phones, `/import?scan=1` starts the camera)
- `priv/gettext/`: `*.pot` templates, German translations in `de/LC_MESSAGES/`
- `priv/repo/migrations/`: generated migrations, `priv/resource_snapshots/`: their Ash snapshots
- `docs/adr/`: architecture decision records
- `.github/`: Dependabot (`dependabot.yml`), CodeQL (`workflows/codeql.yml`) and CI with Sobelow
  (`workflows/ci.yml`), see SECURITY.md
- `docs/agents/phoenix.md`: Phoenix 1.8 guidelines for AI assistants (from the generator)

## Sign-in and authorization (`Plattensammlung.Accounts`, ADR 0005)

- AshAuthentication: `User` (magic link, API key), `Token`, `ApiKey`. Passkeys are built in
  the project: resource `Passkey`, protocol in `Accounts.WebAuthn` (wax_), endpoints in
  `PasskeyController`, JS in `assets/js/hooks/passkey.js`.
- Only addresses from `ALLOWED_EMAILS` (`config :plattensammlung, :allowed_emails`) can sign
  in (`Accounts.allowed_email?/1`).
- **Shared albums (ADR 0016):** albums and artists are shared, `Copy` and `Wish` belong to one
  user (`owner`). Album data is changed by whoever has the album in collection or wishlist;
  copies only by their owner. `owned`, `wanted`, `copy_count` are calculations from the actor's
  point of view (always load them with `actor:`, otherwise they are `false`). Collection,
  wishlist and statistics show the actor's without `owner_id` (preparation `ScopeToOwner`),
  without a status the whole catalogue. Album data may also be changed by everyone while no one has the album (like deleting it):
  calculation `editable`, same expression as the update policy. Edit pages check with
  `Ownership.require_editable/2` (load `:editable`)
  or `require_copy_owner/2`; `album.copies` holds the copies of all users, load your own with
  `Ownership.own_copies(user)`. Show other users only `Accounts.list_collectors` (ID + display
  name), never the e-mail address.
- **Deleting an account (ADR 0023):** `Accounts.delete_account/2` (action `User.delete_account`,
  change `Accounts.Changes.DeleteAccountData`). New user-owned data needs `on_delete: :delete`
  on its reference or a step there.
- `Copy.purchased_on` and `Copy.notes` are readable only by the owner (field policy). Others
  get `%Ash.ForbiddenField{}` (truthy!); in the API the fields are missing. Add new private
  fields to `field_policies` there.
- **All Records actions need an actor.** In LiveViews pass `actor: socket.assigns.current_user`,
  create AshPhoenix forms with `actor:`. In changes pass the options on with
  `Ash.Context.to_opts(context)`. Only seeds, test setup and system tasks (startup cleanup,
  metrics) use `authorize?: false`.
- LiveViews live in `ash_authentication_live_session :authenticated` in the router. New pages
  go there and pass `current_user={@current_user} current_path={@current_path}` to
  `Layouts.app` (`@current_path` comes from the `on_mount` hook `PlattensammlungWeb.Nav` and
  marks the active page in the navigation).
- Create test data in web tests with `actor: user` (otherwise the owner is missing); reading
  for assertions may use `authorize?: false`.
- Tests: `register_and_sign_in_user` / `sign_in_user/2` (ConnCase), `user_fixture/1`,
  `api_key_fixture/1` (`test/support/accounts_fixtures.ex`), `SoftAuthenticator` for
  passkeys. `test@example.com` is on the test allow list.

## Domain `Plattensammlung.Records`

Files: `lib/plattensammlung/records.ex` (domain with code interface),
`lib/plattensammlung/records/` (resources `Artist`, `Album`, `Copy`, `Wish`, enum `Condition`,
`changes/`).

Most important code interface functions (each also with `!`):

- `add_to_collection(artist_name, title, attrs)`: reuse or create the album
  (`Records.AddAlbum`: Discogs ID, MusicBrainz ID, artist + title) and add an own copy.
  Pressing details go under `attrs.copy`.
- `add_to_wishlist(artist_name, title, attrs)`: reuse or create the album, add an own wish.
  Both are generic actions (no surrounding transaction) and only fill gaps when reusing an
  album (`Album.complete`).
- `remove_album(album_id)`: delete the own copies and wish, the album only once no one has it.
- `merge_albums(source_id, target_id)` (ADR 0024, `Records.MergeAlbums`, policy check
  `Checks.CanMerge`): moves copies and wishes of all users, fills gaps (`Album.absorb`), deletes
  the source. `Copy.move`, `Wish.move` and `Album.absorb` are internal steps of it only.
  New per-user data that points to an album must be moved there too.
- `mark_wanted(album)` / `unmark_wanted(album)`, `add_wish(album_id)`: the own wish.
- `add_copy(album_id, attrs)`: add another copy; removes the album from the own wishlist.
- `search_albums(query \\ nil, status \\ nil)`, `list_collection()`, `list_wishlist()`.
  Order with the argument `order` (`:title`, `:artist`, `:year`, `:added`; preparation
  `SortAlbums`, sort keys are the calculations `artist_sort_key` and `added_at`). Not `sort`:
  that name is taken by the JSON:API sort parameter of the index route.
  Careful: with optional arguments always pass all of them before the options
  (`search_albums(nil, nil, actor: user)`), otherwise the keyword list is read as an argument.
- `get_album(id, load: [:artist, :copies, :owned, :copy_count, :discogs_url])`

Rules:

- Artists are found or created by name (change `FindOrCreateArtist`), case-insensitively
  (`:ci_string` = citext).
- **Artists are shared (ADR 0015):** rename/delete only while no other user has an album of
  theirs; delete only without albums. `RemoveOrphanedArtist` and `Records.ArtistCleanup`
  remove artists without albums (also at app start).
- "Do I own it" is the calculation `owned` (does an own copy exist?). It is never stored.
- Adding an own copy deletes the own wish (change `RemoveFromWishlist`, `Records.Wishlist`).
- Search status `:other`: albums without own copy and without own wish ("Not mine").
- A copy deliberately has no storage location and no purchase price. `Copy.format` is a list.
- An album is deleted only once no one has it (destroy policy); its cover and, if now unused,
  its artist go with it. Use `destroy_album` directly only for such albums.
- **Limits (ADR 0006, addendum):** text fields and lists have `constraints max_length`, years
  1900–2100, Discogs IDs `min: 1`, barcode 8–14 digits (change `NormalizeBarcode` +
  `validate match`). New fields always get a limit, the form field a matching `maxlength`.
  Accept URL parameters in LiveViews only as strings and cut them (see
  `AlbumLive.Index.blank_to_nil/1`).

## Import (`Plattensammlung.Lookup`)

- `Plattensammlung.Lookup.search/1` is the facade: 8–14 digits are a barcode (the first
  source with a hit wins, Discogs before MusicBrainz), anything else is a text search in all
  sources, merged per album.
- Clients: `Lookup.Discogs` (token required) and `Lookup.MusicBrainz` (+ Cover Art Archive).
  All HTTP calls go through `Lookup.HTTP.new/1` (Req).
- In Ash the import is the **generic action** `Album.lookup` (`Records.lookup_albums/1`). It
  returns `Records.LookupResult`, an embedded resource that is never stored.
- Taking over a result: `Lookup.album_attrs/1` and `Lookup.copy_attrs/1` →
  `add_to_collection`/`add_to_wishlist`.
- Covers: the change `StoreCover` downloads remote URLs before the transaction
  (`Plattensammlung.Covers`, served at `/covers`). If that fails, the remote URL stays.
- Camera scan: JS hook `BarcodeScanner` in `assets/js/hooks/barcode_scanner.js` (registered in
  `app.js`). It sends the LiveView event `"scanned"` to `ImportLive`.
- **Browser tests (ADR 0025):** `test/plattensammlung_web/browser/`,
  `use PhoenixTest.Playwright.Case, async: true`, helpers in `test/support/browser_helpers.ex`
  (`sign_in/2`, `hover/2`, setup `stub_lookups`). `conn` is a Playwright session. Wait for
  `body .phx-connected` before interacting; LiveView sets a select's choice as a property
  (`assert_has(sel, value: …)`, not `option[selected]`). Confirmation dialogs are accepted.
  The test server runs on port 4012 with the Ecto sandbox via user agent (`LiveSandbox`).
- **Parallel tests and unique names:** every async test holds its sandbox transaction for its
  whole run. Two tests creating the same artists in different orders can deadlock on the
  unique index (`FindOrCreateArtist`). New tests use their own artist names instead of the
  common "The Beatles"/"Can"/"Kraftwerk".
- **Tests never go to the network**: `config/test.exs` routes Req to the stub
  `Plattensammlung.LookupStub` (`test/support/lookup_stub.ex`).

## JSON API (AshJsonApi)

- Routes are in `Plattensammlung.Records` under `json_api do routes … end`. Every route calls an
  existing action, no API-specific logic. Add new actions the API needs there.
- Serialization per resource in `json_api do`: `type`, `includes`, `default_fields`.
  Aggregates and calculations only appear when listed in `default_fields`. Private
  attributes (e.g. timestamps) must **not** be listed there, otherwise `fields[…]` rejects them.
- Generic actions (`add_to_collection`, `add_to_wishlist`, `remove`) answer with plain JSON;
  `Album.id` is public and in `default_fields` so the answer contains it.
- Router: `lib/plattensammlung_web/ash_json_api_router.ex` (OpenAPI title, server URL, bearer auth).
- PATCH routes run atomically first. If the response loads calculations, the action must not
  be atomic (see `mark_wanted`).
- Tests: `test/plattensammlung_web/api/`, with the headers `accept` and `content-type` set to
  `application/vnd.api+json`.

## Assets

- npm packages are in `assets/package.json` (`mix setup` runs `npm install` via `npm_install/1`
  in `mix.exs`), currently only `@zxing/*`. Node version in `.nvmrc`.
- esbuild builds ES modules with code splitting. Load large, rarely used libraries with
  `await import("…")` so they end up in their own chunk.

## Matching and covers

- `Album.find_matches` / `Album.apply_match` (ADR 0007, addendum): `Records.AlbumMatch`
  computes the changes (`changes/3`, `copy_changes/3`, `labels/1`), both for the preview and
  for saving. Page: `AlbumLive.Match` (`/albums/:id/match`).
- Covers: `Album.upload_cover` (argument `:image`, type `:file`, image type by magic bytes in
  `Covers.store_file/1`) and `Album.remove_cover`. Upload in `AlbumLive.Show` with LiveView
  `allow_upload` and `auto_upload`.
- **Cover sources (ADR 0014):** `cover_url` from outside only empty or https from
  `:cover_hosts` (validation `CoverSource`, `Covers.allowed_url?/1`). Local `/covers/…` paths
  are only set by the app (download, upload). Add new import sources with images there.
- On failure only delete files the action stored itself (`changeset.context[:stored_cover]`),
  never a path from the input.
- Cover files: store the new file before the transaction, delete the old one only after a
  successful commit, remove the new one again on errors. `Covers.cleanup_orphans/0` deletes
  unreferenced files (older than 1 h) at app start (`:cleanup_covers_on_start`, off in tests).

## Streaming links (ADR 0012)

- `Album.spotify_album_id` / `tidal_album_id` store IDs; links via `Records.Streaming` or the
  calculations `spotify_url` / `tidal_url`.
- Lookup: `Lookup.StreamingLinks.find/1` (Discogs → MusicBrainz, otherwise artist + title;
  Wikidata, MusicBrainz releases), triggered by the change `FillStreamingLinks` (import,
  matching, changed link, `Album.find_streaming_links`). Spotify links in the import:
  `Lookup.Spotify`.
- Tests: `LookupStub` answers Wikidata and MusicBrainz; it is active by default in
  DataCase/ConnCase so no test goes to the network.

## Statistics and export (ADR 0010)

- `Album.statistics` is a generic action implemented in `Records.Statistics`
  (`use Ash.Resource.Actions.Implementation`). Totals with `Ash.count/2` / `Ash.sum/3`,
  breakdowns as lists of `%{label, count, filter}`.
- `Records.Export`: `csv/1` (all fields) and `json_ld/2` (schema.org, without private fields),
  the actor's collection and wishlist with only their own copies. Downloads via
  `ExportController` (`/export/plattensammlung.csv|.jsonld`).
- Charts: `PlattensammlungWeb.StatsComponents` (`stat_tile`, `bar_chart`). Bars in one colour,
  values always as text, chart as a `<table>`.
- Drill-down: statistics entries have a `filter` (arguments for `Album.search`: `genre`,
  `decade`, `artist`, `condition`); the album list reads them from the URL and shows them as chips.

## Operations (ADR 0011, `deploy/`)

- Production: release image (Dockerfile, `rel/overlays/bin/start` = migrate + start), TrueNAS
  custom app (`deploy/truenas-compose.yaml`), TLS at nginx-proxy-manager.
- **Optional path prefix (`PHX_PATH`, ADR 0018):** the proxy strips it, the app adds it to
  links. Paths only via `~p`, in JavaScript via `appPath()` (`assets/js/app_path.js`), absolute
  URLs with a path via `PublicUrl.url/2`. Prefix local cover paths with `Endpoint.path/1` when
  displaying them. Never write `"/…"` as a fixed string in JS or strings.
- **Always build the public address with `PlattensammlungWeb.PublicUrl.base_url/1`**, never
  from `conn.host`/`conn.port`: behind the proxy the app only sees `http://nas:4000`. In prod it
  comes from `PHX_HOST` (`:public_url`).
- Mail in prod via SMTP (`runtime.exs`, `gen_smtp`), sender from `MAIL_FROM` (`:mail_from`).
- Add new required environment variables to `deploy/app.env.example` and `deploy/README.md`.
- Nothing local in the image: `.dockerignore` excludes `uploads/`, `priv/cert/` and `deploy/`.

## Metrics and traces (ADR 0019)

- `Plattensammlung.Metrics`: all Prometheus metrics (Peep), own events (`sign_in/2`,
  `magic_link_request/1`, `[:plattensammlung, :data]` every minute). `PlattensammlungWeb.MetricsPlug`
  serves `/metrics` on its own port (`METRICS_PORT`, off = nil).
- Tags only with few values: route pattern, view, action, user ID; never paths, album IDs, IPs.
- Counters that alerts check with `increase()`: define them as `sum` and start them at 0 in
  `Metrics.init_counters/0` (otherwise Prometheus doesn't see the first increase).
- Alerts: `deploy/observability/grafana/provisioning/alerting/` (read-only in Grafana). Write
  `$` in annotations as `$$`, otherwise Grafana replaces it with environment variables.
- Traces: OpenTelemetry for Bandit, Phoenix/LiveView, Ecto, Ash (`config :ash, :tracer`) and Req
  (`OpentelemetryReq.attach` in `Lookup.HTTP`). Export only with `OTEL_EXPORTER_OTLP_ENDPOINT`.
  The minute data measurement is not traced (non-sampled parent span).
- Operations: `deploy/observability/` (Prometheus, Tempo, Grafana with dashboards); locally the
  same files via the Compose profile `observability` (`prometheus.local.yml` scrapes
  `host.containers.internal:9568`). Tempo 3: retention is under `backend_scheduler`/`backend_worker`.
- The metrics port only starts when the app serves HTTP (`mix phx.server`), not with `mix run`
  or seeds. In dev on 9568, bound to `127.0.0.1` only.
- Tests: background data measurement off (`measure_data?: false`); tests call
  `Metrics.measure_data/0` themselves.
- Dependabot also updates the observability images; major updates (e.g. Tempo 3) can change the
  configuration. Start the local stack before merging such a PR.

## Languages (ADR 0021)

- Every interface text goes through Gettext with an **English msgid**: `gettext("Collection")`,
  `ngettext("1 album", "%{count} albums", n)`, values as bindings
  (`gettext("Collection of %{name}", name: …)`), never by concatenating sentence parts.
  Context for short ambiguous words: `pgettext("navigation", "Add")`.
- After adding texts: `mix gettext.extract --merge`, then fill in the German `msgstr` in
  `priv/gettext/de/LC_MESSAGES/default.po` (and `errors.po` for new validation messages).
  `test/plattensammlung_web/locale_test.exs` fails while a German translation is missing or
  fuzzy; remove `#, fuzzy` flags after checking the text.
- Language order: `User.locale` (account page) → `Accept-Language` → English
  (`PlattensammlungWeb.Locale`). LiveViews get it through the `on_mount` hook in both live
  sessions; new live sessions need `{PlattensammlungWeb.Locale, :default}` too.
- Ash actions, the API and exports stay English and language-neutral; translate in the web
  layer (e.g. `StatsLive.translate/1`, `field_label/1`). Validation messages are English and
  get their German text in `errors.po`.
- Labels that depend on the language must not be module attributes (compile time); build them
  in a function (see `fields/0` in the forms).
- JavaScript texts come from `data-msg-*` attributes rendered with `gettext`.
- E-mails: wrap the building of the mail in `Gettext.with_locale/3` with the language of the
  request (magic link: `locale` in the action context).
- Dates with `format_date/1`, user names for others with `user_name/1`.
- `de/LC_MESSAGES/auth.po` (texts of `AuthOverrides`) is not extracted; keep it in sync by hand.
- Tests assert English texts; German is tested with `Accept-Language: de`.

## Phoenix guidelines

When working on web code (LiveView, HEEx, components, router) **read and follow
[docs/agents/phoenix.md](docs/agents/phoenix.md)**. The file comes from the Phoenix generator.
Deviating from it: data access goes through Ash instead of Ecto contexts.

## Pitfalls

- **Design:** colours only via the daisyUI theme tokens in `assets/css/app.css` (`primary` =
  label vermilion, `accent` = amber for the wishlist, `neutral` = the record), never fixed
  colours, so both themes work. Headings use `--font-display` (rounded system font, no web
  font). The back link above a page is `<.back_link>` (an inline link ignores `space-y-*`).
- **View transitions** (`app.js`): live navigation runs inside `document.startViewTransition`;
  elements with the same `view-transition-name` on both pages morph (covers: `cover-<id>`, via
  `<.cover morph>`). Names must be unique per page.
- **Cover colour** (hook `CoverTint`, `assets/js/hooks/cover_tint.js`): computed in the browser,
  not stored. Only local covers (`local_cover_path/1`), remote images can't be read (canvas taint).
  On the album list `ListTint` tints the page background (`#list-tint`, softer) in the colour of
  the album under the mouse, after a short pause and only for mouse pointers. Elements carry
  `data-cover` (local cover) and `data-color` (label colour, the fallback). `--cover-tint` and
  `--tint-strength` are registered with `@property`, so changes blend. The tint on screen is
  carried over to the next page (`startFrom` in `cover_tint.js`): the new page starts in that
  colour without transition and blends to its own, so page changes don't flash back to neutral.
- **List memory** (`assets/js/hooks/list_memory.js`): `RememberList` on the album list keeps its
  URL, title, view and order in `sessionStorage`; `BackLink` on the album page points back there.
  View and order reach the server as connect params (`list_prefs`, `params` is a function in
  `app.js` so every live navigation sends them) and apply when the URL has no `?view=`/`?sort=`.
  The URL keeps only explicit choices. Connect params are user input: only known values.
- Album page: rarely used actions (edit, match, remove) sit in the "⋯" menu next to the title;
  "Another copy" is in the heading of the own copies.
- Percentages in `padding` refer to the containing block, not the element: inside small round
  elements (labels) size text with container units (`@container`, `cqw`) and limit its width.
- **Icons:** Tailwind only generates `hero-*` classes it finds literally in the source; never
  build icon names at runtime (`@icon <> "-solid"`), pass both names instead.

- **CSP** (`Plugs.ContentSecurityPolicy`, ADR 0014): inline scripts need
  `nonce={assigns[:csp_nonce]}`, inline `<style>` is forbidden, `style` attributes are allowed.
  Images only from the app and the cover sources. `/dev` runs without CSP (pipeline `:dev_browser`).
- AshAuthentication has no built-in passkey strategy, see [ADR 0005](docs/adr/0005-passkey-login.md).
- Forms use `AshPhoenix.Form` (`for_create`/`for_update`/`for_action`, `validate`, `submit`),
  no Ecto changesets.
- Optional form fields like in Apple's Contacts app: `PlattensammlungWeb.OptionalFields`
  (`optional_field`, `add_field_buttons`, `show/3`, `hide/3`). Hidden fields are sent as an empty
  value, so "−" clears the value. Required fields are always visible.
- Tag fields with suggestions: `PlattensammlungWeb.TagInput` (`tag_input`, `tag_entry_forms`,
  `add/4`, `remove/4`, `clear/2`). `multiple: true` for lists (genres, format), otherwise exactly
  one value (label, country). The input belongs to its own form `#<field>-entry` outside the main
  form, so Enter adds a tag instead of saving. Lists arrive as `form[field][]` and are cleaned up
  with `prepare_params`.
- Buttons with an icon: no `phx-disable-with` (it only restores the text, the icon disappears).
  Use `<.loading_icon name="…" />` and `phx-click-loading:pointer-events-none` on the button.
- The cover URL is not edited by hand; the form only shows a preview.
- MusicBrainz allows about 1 request per second: `Lookup.Throttle` keeps the gap for all of the
  app's requests (Req step in `MusicBrainz.get/2`, ADR 0017). On 503 Req retries automatically.
- **Rate limits (ADR 0017):** magic links per address and IP (`Accounts.RequestMagicLink`,
  `Plattensammlung.RateLimit` = Hammer/ETS). Always get the client IP via
  `PlattensammlungWeb.ClientIp` (`X-Forwarded-For`, last entry; in LiveViews `from_socket/1` in mount).
- The Cover Art Archive images are hosted on archive.org, which is sometimes unreachable. Then
  the remote URL stays and the interface shows the placeholder record.
- `LAN=1 mix phx.server` opens HTTPS on port 4001 for the whole Wi-Fi (ADR 0008). The
  certificate is in `priv/cert/` (not in Git). `/dev` (mailbox with sign-in links) is only
  reachable from localhost.
- Code interfaces with optional arguments: pass options only after all arguments, otherwise the
  keyword list is read as an argument.
- With `podman compose`, the external `docker-compose` does the work. The note about it in the
  output is harmless.
