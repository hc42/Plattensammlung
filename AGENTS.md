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
    `Show` (`/albums/:id`, „Auf meine Wunschliste“ = `Records.copy_to_wishlist/2`),
    `Form` (Schnellerfassung `/albums/new`, Bearbeiten `/albums/:id/edit`)
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
- **Gemeinsame Alben (ADR 0016):** Alben und Künstler sind gemeinsam, `Copy` und `Wish`
  gehören einem User (`owner`). Albumdaten ändert, wer das Album in Sammlung oder Wunschliste
  hat; Exemplare nur ihr Besitzer. `owned`, `wanted`, `copy_count` sind Berechnungen aus Sicht
  des Actors (immer mit `actor:` laden, sonst `false`). Sammlung/Wunschliste/Statistik zeigen
  ohne `owner_id` die des Actors (Preparation `ScopeToOwner`), ohne Status den ganzen Katalog.
  Bearbeiten-Seiten prüfen mit `Ownership.require_holder/2` bzw. `require_copy_owner/2`;
  `album.copies` enthält Exemplare aller User, eigene mit `Ownership.own_copies(user)` laden.
  Anderen Usern nur `Accounts.list_collectors` (ID + Anzeigename) zeigen, nie die E-Mail.
- `Copy.purchased_on` und `Copy.notes` sind per Field Policy nur für den Besitzer lesbar.
  Andere bekommen `%Ash.ForbiddenField{}` (truthy!), in der API fehlen die Felder.
  Neue private Felder dort in `field_policies` eintragen.
- **Alle Records-Actions brauchen einen Actor.** In LiveViews `actor: socket.assigns.current_user`
  übergeben, AshPhoenix-Formulare mit `actor:` erzeugen. In Changes die Optionen mit
  `Ash.Context.to_opts(context)` weiterreichen. Nur Seeds und Test-Vorbereitung nutzen
  `authorize?: false`.
- LiveViews liegen in `ash_authentication_live_session :authenticated` im Router. Neue
  Seiten gehören dort hinein und übergeben `current_user={@current_user}` an `Layouts.app`.
- Testdaten in Web-Tests mit `actor: user` anlegen (sonst fehlt der Besitzer);
  Lesen zum Prüfen darf `authorize?: false` nutzen.
- Tests: `register_and_sign_in_user` / `sign_in_user/2` (ConnCase), `user_fixture/1`,
  `api_key_fixture/1` (`test/support/accounts_fixtures.ex`), `SoftAuthenticator` für
  Passkeys. `test@example.com` ist in der Test-Freigabeliste.

## Domain `Plattensammlung.Records`

Dateien: `lib/plattensammlung/records.ex` (Domain mit Code Interface),
`lib/plattensammlung/records/` (Resources `Artist`, `Album`, `Copy`, Enum `Condition`,
`changes/`).

Wichtigste Funktionen des Code Interface (jeweils auch mit `!`):

- `add_to_collection(artist_name, title, attrs)`: Album wiederverwenden oder anlegen
  (`Records.AddAlbum`: Discogs-ID, MusicBrainz-ID, Künstler + Titel) und eine eigene Copy anlegen.
  Pressungsdetails stehen unter `attrs.copy`.
- `add_to_wishlist(artist_name, title, attrs)`: Album wiederverwenden oder anlegen, eigenen Wish anlegen.
  Beide sind generische Actions (keine Transaktion drumherum) und füllen beim
  Wiederverwenden nur Lücken (`Album.complete`).
- `remove_album(album_id)`: eigene Copies und eigenen Wish löschen, das Album erst, wenn es niemand mehr hat.
- `mark_wanted(album)` / `unmark_wanted(album)`, `add_wish(album_id)`: eigener Wunsch.
- `add_copy(album_id, attrs)`: weiteres Exemplar anlegen, entfernt das Album von der Wunschliste.
- `search_albums(query \\ nil, status \\ nil)`, `list_collection()`, `list_wishlist()`.
  Achtung: Bei optionalen Argumenten immer alle angeben, bevor Optionen folgen
  (`search_albums(nil, nil, actor: user)`), sonst wird die Keyword-Liste als Argument gelesen.
- `get_album(id, load: [:artist, :copies, :owned, :copy_count, :discogs_url])`

Regeln:

- Artists werden über den Namen gefunden oder angelegt (Change `FindOrCreateArtist`),
  ohne Beachtung der Groß- und Kleinschreibung (`:ci_string` = citext).
- **Künstler sind gemeinsam (ADR 0015):** umbenennen/löschen nur, wenn kein anderer User ein
  Album davon hat; löschen nur ohne Alben. Künstler ohne Alben räumt `RemoveOrphanedArtist`
  bzw. `Records.ArtistCleanup` auf (auch beim App-Start).
- „Besitze ich“ ist das Aggregate `owned` (existiert eine Copy?). Es wird nie gespeichert.
- Eine eigene Copy anzulegen löscht den eigenen Wish (Change `RemoveFromWishlist`, `Records.Wishlist`).
- Such-Status `:other`: Alben ohne eigene Copy und ohne eigenen Wish („Nicht bei mir“).
- Copy hat bewusst keinen Lagerort und keinen Kaufpreis mehr. `Copy.format` ist eine Liste.
- Ein Album wird nur gelöscht, wenn es niemand mehr hat (Destroy-Policy); dabei gehen Cover und
  gegebenenfalls der nun unbenutzte Artist mit. Direkt `destroy_album` nur für solche Alben.
- **Grenzen (ADR 0006, Nachtrag):** Textfelder und Listen haben `constraints max_length`, Jahre
  1900–2100, Discogs-IDs `min: 1`, Barcode 8–14 Ziffern (Change `NormalizeBarcode` + `validate match`).
  Neue Felder bekommen immer eine Grenze, das Formularfeld ein passendes `maxlength`.
  URL-Parameter in LiveViews nur als String annehmen und kürzen (siehe `AlbumLive.Index.blank_to_nil/1`).

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

- npm-Pakete liegen in `assets/package.json` (`mix setup` führt über `npm_install/1` in
  `mix.exs` `npm install` aus und bricht mit Hinweis ab, wenn npm fehlt), derzeit nur
  `@zxing/browser`. Node-Version in `.nvmrc`. Beim Besitzer wird nvm verzögert geladen:
  In frischen Terminals ist `npm` erst nach `nvm use` verfügbar.
- esbuild baut ES-Module mit Code-Splitting. Große, selten gebrauchte Bibliotheken per
  `await import("…")` laden, damit sie in einem eigenen Chunk landen.

## Abgleich und Cover

- `Album.find_matches` / `Album.apply_match` (ADR 0007, Nachtrag): Änderungen berechnet
  `Records.AlbumMatch` (`changes/3`, `copy_changes/3`, `labels/1`), sowohl für die Vorschau
  als auch fürs Speichern. Seite: `AlbumLive.Match` (`/albums/:id/match`).
- Cover: `Album.upload_cover` (Argument `:image`, Typ `:file`, Bildtyp per Magic Bytes in
  `Covers.store_file/1`) und `Album.remove_cover`. Upload in `AlbumLive.Show` per LiveView
  `allow_upload` mit `auto_upload`.
- **Cover-Quellen (ADR 0014):** `cover_url` von außen nur leer oder https von `:cover_hosts`
  (Validation `CoverSource`, `Covers.allowed_url?/1`). Lokale `/covers/…`-Pfade setzt nur die App
  (Download, Upload, `copy_to_wishlist`). Neue Import-Quellen mit Bildern dort eintragen.
- Beim Fehlschlag nur Dateien löschen, die die Action selbst angelegt hat
  (`changeset.context[:stored_cover]`), nie einen Pfad aus der Eingabe.
- Cover-Dateien: neue Datei vor der Transaktion speichern, alte erst nach erfolgreichem Commit
  löschen, bei Fehlern die neue wieder entfernen. `Covers.cleanup_orphans/0` löscht
  unreferenzierte Dateien (älter als 1 h) beim App-Start (`:cleanup_covers_on_start`, in Tests aus).

## Streaming-Links (ADR 0012)

- `Album.spotify_album_id` / `tidal_album_id` speichern IDs; Links über `Records.Streaming`
  bzw. die Calculations `spotify_url` / `tidal_url`.
- Suche: `Lookup.StreamingLinks.find/1` (Discogs→MusicBrainz, sonst Künstler + Titel; Wikidata, MusicBrainz-Releases),
  ausgelöst vom Change `FillStreamingLinks` (Import, Abgleich, geänderte Verknüpfung,
  `Album.find_streaming_links`). Spotify-Links im Import: `Lookup.Spotify`.
- Tests: `LookupStub` beantwortet Wikidata und MusicBrainz; er ist in DataCase/ConnCase
  standardmäßig aktiv, damit kein Test ins Netz geht.

## Statistik und Export (ADR 0010)

- `Album.statistics` ist eine generische Action, implementiert in `Records.Statistics`
  (`use Ash.Resource.Actions.Implementation`). Summen per `Ash.count/2` / `Ash.sum/3`,
  Aufschlüsselungen als Listen von `%{label, count}`.
- `Records.Export`: `csv/1` (alle Felder) und `json_ld/2` (schema.org, ohne private Felder).
  Downloads über den `ExportController` (`/export/plattensammlung.csv|.jsonld`).
- Diagramme: `PlattensammlungWeb.StatsComponents` (`stat_tile`, `bar_chart`). Balken in einer
  Farbe, Werte immer als Text, Diagramm als `<table>`.
- Drill-down: Statistik-Einträge haben `filter` (Argumente für `Album.search`: `genre`,
  `decade`, `artist`, `condition`); die Albenliste liest sie aus der URL und zeigt sie als Chips.

## Betrieb (ADR 0011, `deploy/`)

- Produktion: Release-Image (Dockerfile, `rel/overlays/bin/start` = migrieren + starten),
  TrueNAS Custom App (`deploy/truenas-compose.yaml`), TLS bei nginx-proxy-manager.
- **Optionaler Pfad-Präfix (`PHX_PATH`, ADR 0018):** Der Proxy schneidet ihn ab, die App setzt
  ihn in Links. Pfade nur über `~p`, in JavaScript über `appPath()` (`assets/js/app_path.js`),
  absolute URLs mit Pfad über `PublicUrl.url/2`. Lokale Cover-Pfade beim Anzeigen mit
  `Endpoint.path/1` versehen. Nie `"/…"` fest in JS oder Strings schreiben.
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

- **CSP** (`Plugs.ContentSecurityPolicy`, ADR 0014): Inline-Skripte brauchen
  `nonce={assigns[:csp_nonce]}`, inline `<style>` ist verboten, `style`-Attribute sind erlaubt.
  Bilder nur von der App und den Cover-Quellen. `/dev` läuft ohne CSP (Pipeline `:dev_browser`).

- AshAuthentication hat keine eingebaute Passkey-Strategie, siehe [ADR 0005](docs/adr/0005-passkey-login.md).
- Formulare nutzen `AshPhoenix.Form` (`for_create`/`for_update`, `validate`, `submit`), keine Ecto-Changesets.
- Optionale Formularfelder wie in Apples Kontakte-App: `PlattensammlungWeb.OptionalFields`
  (`optional_field`, `add_field_buttons`, `show/3`, `hide/3`). Ausgeblendete Felder werden als
  leerer Wert gesendet, "−" löscht also den Wert. Pflichtfelder bleiben immer sichtbar.
- Tag-Felder mit Vorschlägen: `PlattensammlungWeb.TagInput` (`tag_input`, `tag_entry_forms`,
  `add/4`, `remove/4`, `clear/2`). `multiple: true` für Listen (Genres, Format), sonst genau ein
  Wert (Label, Land). Die Eingabe gehört zu einem eigenen Formular `#<feld>-entry` außerhalb des
  Hauptformulars, damit Enter einen Tag hinzufügt statt zu speichern. Listen kommen als
  `form[feld][]` an und werden per `prepare_params` bereinigt.
- Buttons mit Icon: kein `phx-disable-with` (stellt nur den Text wieder her, das Icon
  verschwindet). Stattdessen `<.loading_icon name="…" />` und am Button
  `phx-click-loading:pointer-events-none`.
- Die Cover-URL wird nicht von Hand bearbeitet; das Formular zeigt nur eine Vorschau.
- MusicBrainz erlaubt etwa 1 Anfrage pro Sekunde: `Lookup.Throttle` hält den Abstand für alle
  Anfragen der App (Req-Step in `MusicBrainz.get/2`, ADR 0017). Bei 503 wiederholt Req automatisch.
- **Rate Limits (ADR 0017):** Anmeldelinks pro Adresse und IP (`Accounts.RequestMagicLink`,
  `Plattensammlung.RateLimit` = Hammer/ETS). Client-IP immer über `PlattensammlungWeb.ClientIp`
  (`X-Forwarded-For`, letzter Eintrag; in LiveViews `from_socket/1` im Mount).
- Die Bilder des Cover Art Archive liegen auf archive.org, das zeitweise nicht erreichbar ist.
  Dann bleibt die Remote-URL stehen und die Oberfläche zeigt die Platzhalter-Platte.
- `LAN=1 mix phx.server` öffnet HTTPS auf Port 4001 für das ganze WLAN (ADR 0008). Das
  Zertifikat liegt in `priv/cert/` (nicht im Git). `/dev` (Postfach mit Anmeldelinks) ist
  nur von localhost aus erreichbar.
- Code Interfaces mit optionalen Argumenten: Optionen erst nach allen Argumenten angeben,
  sonst wird die Keyword-Liste als Argument gelesen.
- Bei `podman compose` übernimmt das externe `docker-compose` die Ausführung. Der Hinweis
  dazu in der Ausgabe ist harmlos.
