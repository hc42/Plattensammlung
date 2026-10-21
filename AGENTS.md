# AGENTS.md

Hinweise für KI-Assistenten (Claude Code, Codex usw.) und Mitwirkende an diesem Projekt.

## Projekt

Web-Anwendung zur Verwaltung einer privaten Schallplattensammlung mit Elixir, Phoenix
und dem Ash Framework. Überblick und Fahrplan stehen in der [README.md](README.md), die
Begründungen für Entscheidungen in [docs/adr/](docs/adr/).

## Zusammenarbeit

- Der Besitzer lernt Ash und Phoenix mit diesem Projekt kennen. Schritte und Ash-Konzepte
  daher kurz erklären, wenn sie neu sind, z. B. Resources, Actions, Relationships,
  Calculations, Aggregates und Policies.
- Die Oberfläche ist auf Deutsch, Texte stehen derzeit direkt in den Templates (noch kein Gettext).
- Mit dem Besitzer wird auf **Deutsch** kommuniziert. Code, Bezeichner und
  Commit-Messages sind auf Englisch, die Dokumentation (README, ADRs) auf Deutsch.
- Erst planen und besprechen, dann bauen. Größere Designentscheidungen vorher abstimmen.

## Dokumentation aktuell halten (Pflicht)

Diese Dokumente **ohne Aufforderung** mitpflegen, sobald sich etwas ändert:

- **README.md**: Status, Funktionsumfang, Technik, Fahrplan, Befehle für die Entwicklung.
- **AGENTS.md**: Konventionen, Befehle, Projektstruktur und Stolperfallen.
- **docs/adr/**: Jede architekturrelevante Entscheidung (Technik, Datenmodell,
  Authentifizierung, Schnittstellen, Deployment) bekommt einen neuen ADR. Dafür die
  Vorlage [docs/adr/template.md](docs/adr/template.md) verwenden und fortlaufend
  nummerieren (`NNNN-kurzer-titel.md`). Bestehende ADRs nicht umschreiben: Wird eine
  Entscheidung geändert, einen neuen ADR anlegen und den alten auf
  „Ersetzt durch ADR NNNN“ setzen. Status-Updates sind erlaubt
  (Vorgeschlagen → Angenommen) und ebenso die Pflege offener Fragen, solange ein ADR
  noch „Vorgeschlagen“ ist.
- Den Index in [docs/adr/README.md](docs/adr/README.md) aktuell halten.

## Technik und Konventionen

- Elixir 1.20 / OTP 29, Phoenix 1.8, Ash 3.x, PostgreSQL 18 (`min_pg_version` im Repo)
- Projekt mit Igniter anlegen und erweitern (`mix igniter.install …`), wo möglich,
  statt Konfiguration von Hand zu schreiben.
- Datenzugriff **nur über Ash**: Code Interfaces der Domain (`define`) statt direktem
  `Ecto.Repo`-Zugriff.
- Migrationen mit `mix ash.codegen <name>` erzeugen, nicht von Hand schreiben.
- Geschäftslogik gehört in Ash Actions, Changes und Validations, nicht in LiveViews
  oder Controller.
- Domain: `Plattensammlung.Records` (Schallplatten), später `Plattensammlung.Accounts`
  (Benutzer und Login).
- Postgres läuft in Podman (`compose.yml`), die Phoenix-App lokal auf dem Mac.

## Befehle

- `podman compose up -d`: Postgres starten (vor allem anderen nötig)
- `mix setup`: Abhängigkeiten, Datenbank, Assets, Seeds
- `mix phx.server`: Entwicklungsserver auf http://localhost:4000
- `mix test`: Tests
- `mix precommit`: **vor jedem Commit ausführen** und alle Probleme beheben
- `mix ash.codegen <name>`: Migrationen aus Ash-Resources erzeugen, danach `mix ash.migrate`
- `mix ash.reset`: Entwicklungsdatenbank neu aufbauen, danach `mix run priv/repo/seeds.exs`

## Projektstruktur

- `lib/plattensammlung/`: Geschäftslogik (Ash-Domains und -Resources, `Repo`)
- `lib/plattensammlung_web/`: Phoenix (Router, LiveViews, Komponenten)
  - `live/album_live/`: `Index` (Sammlung `/` und Wunschliste `/wishlist`, Suche über `?q=`),
    `Show` (`/albums/:id`), `Form` (Schnellerfassung `/albums/new`, Bearbeiten `/albums/:id/edit`)
  - `live/copy_live/form.ex`: Exemplar anlegen (`/albums/:id/copies/new`) und bearbeiten (`/copies/:id/edit`)
  - `live/sign_in_live.ex` (`/sign-in`), `live/account_live.ex` (`/account`: Passkeys, API-Keys)
  - `controllers/passkey_controller.ex`, `controllers/auth_controller.ex`: Anmeldung
  - `live/stats_live.ex` (`/stats`), `controllers/export_controller.ex`: Statistik und Export
  - `live/import_live.ex`: Import-Seite `/import` (Barcode oder Text, Ergebnis per Klick übernehmen)
  - `ash_json_api_router.ex`: JSON:API unter `/api/json`, Swagger-UI unter `/api/json/swaggerui`
  - `components/album_components.ex`: `cover`, `status_badge`, Zustands-Helfer (in allen Views importiert)
- `priv/repo/migrations/`: generierte Migrationen, `priv/resource_snapshots/`: Ash-Snapshots dazu
- `docs/adr/`: Architekturentscheidungen
- `docs/agents/phoenix.md`: Phoenix-1.8-Richtlinien für KI-Assistenten (vom Generator erzeugt)

## Anmeldung und Autorisierung (`Plattensammlung.Accounts`, ADR 0005)

- AshAuthentication: `User` (Magic Link, API-Key), `Token`, `ApiKey`. Passkeys sind selbst
  gebaut: Resource `Passkey`, Protokoll in `Accounts.WebAuthn` (wax_), Endpunkte im
  `PasskeyController`, JS in `assets/js/hooks/passkey.js`.
- Nur Adressen aus `ALLOWED_EMAILS` (`config :plattensammlung, :allowed_emails`) können sich
  anmelden (`Accounts.allowed_email?/1`).
- **Alle Records-Actions brauchen einen Actor.** In LiveViews `actor: socket.assigns.current_user`
  übergeben, AshPhoenix-Formulare mit `actor:` erzeugen. In Changes die Optionen mit
  `Ash.Context.to_opts(context)` weiterreichen. Nur Seeds und Test-Vorbereitung nutzen
  `authorize?: false`.
- LiveViews liegen in `ash_authentication_live_session :authenticated` im Router. Neue
  Seiten gehören dort hinein und übergeben `current_user={@current_user}` an `Layouts.app`.
- Tests: `register_and_sign_in_user` / `sign_in_user/2` (ConnCase), `user_fixture/1`,
  `api_key_fixture/1` (`test/support/accounts_fixtures.ex`), `SoftAuthenticator` für
  Passkeys. `test@example.com` ist in der Test-Freigabeliste.

## Domain `Plattensammlung.Records`

Dateien: `lib/plattensammlung/records.ex` (Domain mit Code Interface),
`lib/plattensammlung/records/` (Resources `Artist`, `Album`, `Copy`, Enum `Condition`,
`changes/`).

Wichtigste Funktionen des Code Interface (jeweils auch mit `!`):

- `add_to_collection(artist_name, title, attrs)`: Album und eine Copy anlegen.
  Pressungsdetails stehen unter `attrs.copy`.
- `add_to_wishlist(artist_name, title, attrs)`: Album ohne Copy mit `wanted: true` anlegen.
- `add_copy(album_id, attrs)`: weiteres Exemplar anlegen, entfernt das Album von der Wunschliste.
- `search_albums(query \\ nil, status \\ nil)`, `list_collection()`, `list_wishlist()`.
  Achtung: Bei optionalen Argumenten immer alle angeben, bevor Optionen folgen
  (`search_albums(nil, nil, actor: user)`), sonst wird die Keyword-Liste als Argument gelesen.
- `get_album(id, load: [:artist, :copies, :owned, :copy_count, :discogs_url])`

Regeln:

- Artists werden über den Namen gefunden oder angelegt (Change `FindOrCreateArtist`),
  ohne Beachtung der Groß- und Kleinschreibung (`:ci_string` = citext).
- „Besitze ich“ ist das Aggregate `owned` (existiert eine Copy?). Es wird nie gespeichert.
- Eine Copy anzulegen setzt `wanted` am Album zurück (Change `RemoveFromWishlist`).
- Ein Album zu löschen löscht seine Copies. Ein Artist mit Alben kann nicht gelöscht werden.

## Import (`Plattensammlung.Lookup`)

- `Plattensammlung.Lookup.search/1` ist die Fassade: 8–14 Ziffern sind ein Barcode
  (erste Quelle mit Treffer gewinnt, Discogs vor MusicBrainz), alles andere ist eine
  Textsuche in allen Quellen, zusammengeführt pro Album.
- Clients: `Lookup.Discogs` (Token nötig) und `Lookup.MusicBrainz` (+ Cover Art Archive).
  Alle HTTP-Aufrufe laufen über `Lookup.HTTP.new/1` (Req).
- In Ash ist der Import die **generische Action** `Album.lookup` (`Records.lookup_albums/1`).
  Sie liefert `Records.LookupResult`, eine Embedded Resource, die nicht gespeichert wird.
- Übernahme: `Lookup.album_attrs/1` und `Lookup.copy_attrs/1` → `add_to_collection`/`add_to_wishlist`.
- Cover: Der Change `StoreCover` lädt Remote-URLs vor der Transaktion herunter
  (`Plattensammlung.Covers`, ausgeliefert unter `/covers`). Schlägt das fehl, bleibt die Remote-URL.
- Kamera-Scan: JS-Hook `BarcodeScanner` in `assets/js/hooks/barcode_scanner.js` (registriert in
  `app.js`). Er sendet das LiveView-Event `"scanned"` an `ImportLive`.
- **Tests gehen nie ins Netz**: `config/test.exs` leitet Req auf den Stub
  `Plattensammlung.LookupStub` (`test/support/lookup_stub.ex`) um.

## JSON-API (AshJsonApi)

- Routen stehen in `Plattensammlung.Records` unter `json_api do routes … end`. Jede Route ruft
  eine vorhandene Action auf, keine API-eigene Logik. Neue Actions, die die API braucht,
  dort eintragen.
- Serialisierung pro Resource in `json_api do`: `type`, `includes`, `default_fields`.
  Aggregate und Berechnungen erscheinen nur, wenn sie in `default_fields` stehen.
  Private Attribute (z. B. Timestamps) dürfen dort **nicht** stehen, sonst lehnt
  `fields[…]` sie ab.
- Router: `lib/plattensammlung_web/ash_json_api_router.ex` (OpenAPI-Titel, Server-URL,
  vorerst ohne Bearer-Auth).
- PATCH-Routen laufen zuerst atomar. Wenn die Antwort Aggregate lädt, muss die Action
  nicht atomar sein (siehe `mark_wanted`).
- Tests: `test/plattensammlung_web/api/`, mit den Headern `accept` und `content-type`
  auf `application/vnd.api+json`.

## Assets

- npm-Pakete liegen in `assets/package.json` (`mix setup` führt `npm install` aus), derzeit
  nur `@zxing/browser`.
- esbuild baut ES-Module mit Code-Splitting. Große, selten gebrauchte Bibliotheken per
  `await import("…")` laden, damit sie in einem eigenen Chunk landen.

## Statistik und Export (ADR 0010)

- `Album.statistics` ist eine generische Action, implementiert in `Records.Statistics`
  (`use Ash.Resource.Actions.Implementation`). Summen per `Ash.count/2` / `Ash.sum/3`,
  Aufschlüsselungen als Listen von `%{label, count}`.
- `Records.Export`: `csv/1` (alle Felder) und `json_ld/2` (schema.org, ohne private Felder).
  Downloads über den `ExportController` (`/export/plattensammlung.csv|.jsonld`).
- Diagramme: `PlattensammlungWeb.StatsComponents` (`stat_tile`, `bar_chart`). Balken in einer
  Farbe, Werte immer als Text, Diagramm als `<table>`.

## Betrieb (ADR 0011, `deploy/`)

- Produktion: Release-Image (Dockerfile, `rel/overlays/bin/start` = migrieren + starten),
  TrueNAS Custom App (`deploy/truenas-compose.yaml`), TLS bei nginx-proxy-manager.
- **Öffentliche Adresse immer über `PlattensammlungWeb.PublicUrl.base_url/1`** bilden,
  nie aus `conn.host`/`conn.port`: Hinter dem Proxy sieht die App nur `http://nas:4000`.
  In prod kommt sie aus `PHX_HOST` (`:public_url`).
- Mail in prod per SMTP (`runtime.exs`, `gen_smtp`), Absender aus `MAIL_FROM` (`:mail_from`).
- Neue Pflicht-Umgebungsvariablen in `deploy/app.env.example` und `deploy/README.md` eintragen.
- Nichts Lokales ins Image: `.dockerignore` schließt `uploads/`, `priv/cert/` und `deploy/` aus.

## Phoenix-Richtlinien

Bei Arbeit an Web-Code (LiveView, HEEx, Komponenten, Router) **unbedingt
[docs/agents/phoenix.md](docs/agents/phoenix.md) lesen und befolgen**. Die Datei stammt
vom Phoenix-Generator. Abweichend davon gilt hier: Datenzugriff über Ash statt über
Ecto-Contexts.

## Stolperfallen

- AshAuthentication hat keine eingebaute Passkey-Strategie, siehe [ADR 0005](docs/adr/0005-passkey-login.md).
- Formulare nutzen `AshPhoenix.Form` (`for_create`/`for_update`, `validate`, `submit`), keine Ecto-Changesets.
  Listen wie `genres` werden im Formular als kommagetrennter Text eingegeben und per `prepare_params` umgewandelt.
- MusicBrainz erlaubt etwa 1 Anfrage pro Sekunde. Bei 503 wiederholt Req automatisch.
- Die Bilder des Cover Art Archive liegen auf archive.org, das zeitweise nicht erreichbar ist.
  Dann bleibt die Remote-URL stehen und die Oberfläche zeigt die Platzhalter-Platte.
- `LAN=1 mix phx.server` öffnet HTTPS auf Port 4001 für das ganze WLAN (ADR 0008). Das
  Zertifikat liegt in `priv/cert/` (nicht im Git). `/dev` (Postfach mit Anmeldelinks) ist
  nur von localhost aus erreichbar.
- Code Interfaces mit optionalen Argumenten: Optionen erst nach allen Argumenten angeben,
  sonst wird die Keyword-Liste als Argument gelesen.
- Bei `podman compose` übernimmt das externe `docker-compose` die Ausführung. Der Hinweis
  dazu in der Ausgabe ist harmlos.
