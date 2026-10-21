# Plattensammlung

Web-Anwendung zum Erfassen und Verwalten einer privaten Schallplattensammlung.

> **Status:** Der Fahrplan ist umgesetzt: Sammlung, Wunschliste, Import, Barcode-Scan, JSON-API, Login per Passkey oder Magic Link, Statistik und Export.

## Ziele

- **Erfassen mit minimalem Aufwand**: Pflicht sind nur Artist und Albumtitel, alles andere ist optional
- Barcode scannen (oder nach Artist und Titel suchen), Daten und Cover von Discogs und MusicBrainz übernehmen, ohne eine Pressungsvariante auswählen zu müssen
- Schnell beantworten: „Habe ich diese Platte?“, mit Links zu Discogs
- **Wunschliste**: Alben merken, die man noch sucht. Der Scan im Plattenladen zeigt sofort „habe ich“ oder „steht auf der Wunschliste“
- Sammlung durchsuchen und filtern, z. B. nach Artist, Genre oder Jahr
- Zugriff über eine Weboberfläche **und** eine JSON-API
- Anmeldung per Passkey
- **Alle Alben** im Blick, auch solche ohne Exemplar und ohne Wunsch („nicht zugeordnet“)
- **Abgleichen** bestehender Alben mit Discogs/MusicBrainz, auch per nachträglichem Barcode-Scan; Pressungsdaten wandern dabei ins Exemplar
- **Cover** hochladen (auch per Handykamera), ersetzen oder entfernen; verwaiste Bilddateien werden aufgeräumt
- Statistik (Umfang, Genres, Jahrzehnte, Zustand) und Export als CSV oder JSON-LD (schema.org)

## Technik

| Bereich | Wahl | Entscheidung |
|---|---|---|
| Sprache / Web | Elixir, Phoenix | [ADR 0002](docs/adr/0002-elixir-phoenix-ash.md) |
| Anwendungs-Framework | Ash (AshPostgres, AshPhoenix) | [ADR 0002](docs/adr/0002-elixir-phoenix-ash.md) |
| Datenbank | PostgreSQL in Podman (Compose) | [ADR 0003](docs/adr/0003-postgresql-mit-podman.md) |
| Oberfläche | Phoenix LiveView und AshJsonApi | [ADR 0004](docs/adr/0004-liveview-und-json-api.md) |
| Login | AshAuthentication, Passkeys über `wax_`, Magic Link als Rückfallebene | [ADR 0005](docs/adr/0005-passkey-login.md) |
| Import | Barcode-Scan im Browser, Discogs API, MusicBrainz und Cover Art Archive | [ADR 0007](docs/adr/0007-barcode-scan-und-import.md) |

## Datenmodell

```
Artist ──< Album ──< Copy
```

- **Album**: das Werk, unabhängig von der Pressung (Pflicht: Titel und Artist; optional: Jahr, Cover, Genres, Wunschliste ja/nein).
  Entspricht der *Release Group* bei MusicBrainz bzw. dem *Master* bei Discogs.
- **Copy**: ein eigenes Exemplar. Album mit Copy = „habe ich“. Alle Pressungs- und Sammlerangaben sind optional (Label, Barcode, Zustand, Kaufdatum, Notizen).

Details stehen in [ADR 0006](docs/adr/0006-datenmodell.md).

## Fahrplan

1. ✅ Projekt anlegen (Phoenix und Ash über Igniter), Postgres über `compose.yml`
2. ✅ Domain `Records` mit Artist, Album und Copy, plus Seed-Daten
3. ✅ LiveView-Oberfläche: Liste, Suche und Filter, Detailseite, Schnellerfassung, Wunschliste
4. ✅ Import: Suche nach Artist und Titel sowie Barcode bei Discogs und MusicBrainz, Cover lokal speichern
5. ✅ Barcode-Scan mit der Kamera im Browser (HTTPS im WLAN: [ADR 0008](docs/adr/0008-https-im-lan.md))
6. ✅ JSON-API (AshJsonApi) mit OpenAPI-Doku ([ADR 0009](docs/adr/0009-gestaltung-der-json-api.md))
7. ✅ Login per Passkey, Magic Link als Rückfallebene, API-Keys ([ADR 0005](docs/adr/0005-passkey-login.md))
8. ✅ Statistik und Export als CSV und JSON-LD ([ADR 0010](docs/adr/0010-statistik-und-export.md))
9. ✅ Betrieb auf dem NAS (TrueNAS, nginx-proxy-manager, SMTP): Anleitung in [deploy/README.md](deploy/README.md), [ADR 0011](docs/adr/0011-betrieb-auf-truenas.md)

## Entwicklung

Voraussetzungen: Elixir 1.20 / OTP 29, Node.js 24 (für die Scanner-Bibliothek) und Podman (mit laufender `podman machine`).
Mit nvm wählt `nvm use` im Projektordner die Version aus `.nvmrc`. Wird nvm verzögert
geladen, muss das vor `mix setup` im jeweiligen Terminal passieren, sonst fehlt `npm`.

```bash
podman compose up -d   # Postgres 18 im Container starten (Port 5432, nur localhost)
mix setup              # Abhängigkeiten, Datenbank anlegen und migrieren, Assets, Seeds
mix phx.server         # App starten: http://localhost:4000
```

Umgebungsvariablen (vor `mix phx.server` setzen):

| Variable | Zweck |
|---|---|
| `ALLOWED_EMAILS` | **Pflicht.** Kommagetrennte E-Mail-Adressen, die sich anmelden dürfen |
| `DISCOGS_TOKEN` | Persönliches Token von https://www.discogs.com/settings/developers. Ohne Token wird nur MusicBrainz durchsucht. |
| `MUSICBRAINZ_CONTACT` | E-Mail oder URL, die MusicBrainz im User-Agent sehen möchte |
| `COVERS_DIR` | Ablage der heruntergeladenen Cover (Standard: `uploads/covers`, nicht im Git) |

```bash
export ALLOWED_EMAILS=du@example.com DISCOGS_TOKEN=dein-token
```

### Anmelden

1. http://localhost:4000 öffnen, die E-Mail-Adresse eingeben und „Anmeldelink senden“ wählen.
2. In der Entwicklung landet die E-Mail im Postfach http://localhost:4000/dev/mailbox.
   Dort den Link öffnen und „Jetzt anmelden“ klicken.
3. Unter „Konto“ (Personen-Symbol) einen Passkey hinzufügen. Danach geht die Anmeldung
   per Fingerabdruck bzw. Face ID.

Ein Passkey gilt nur für die Adresse, unter der er angelegt wurde (`localhost` oder
`<name>.local`).

### Vom Handy aus scannen

Die Live-Kamera braucht HTTPS. Einmalig ein Zertifikat erzeugen:

```bash
mix phx.gen.cert localhost "$(scutil --get LocalHostName).local"
```

Dann den Server mit `LAN=1` starten:

```bash
LAN=1 mix phx.server
```

Auf dem Handy (gleiches WLAN) `https://<LocalHostName>.local:4001/import` öffnen und die
Zertifikatswarnung einmal bestätigen. Den Namen zeigt `scutil --get LocalHostName`.
Ohne HTTPS funktioniert „Foto aufnehmen“. Die App hat noch keinen Login, deshalb nur in
einem vertrauenswürdigen Netz verwenden.

Weitere Befehle:

```bash
mix test               # Tests (legt die Testdatenbank automatisch an)
mix precommit          # Kompilieren mit Warnungen als Fehler, Formatierung, Tests
podman compose down    # Postgres stoppen (Daten bleiben im Volume erhalten)
```

## JSON-API

JSON:API unter `/api/json`, interaktive Doku in der Swagger-UI unter
http://localhost:4000/api/json/swaggerui (Spezifikation: `/api/json/open_api`).

```bash
curl -H "Authorization: Bearer $API_KEY" -H "Accept: application/vnd.api+json" "http://localhost:4000/api/json/albums?query=beatles&include=artist"
```

```bash
curl -X POST http://localhost:4000/api/json/albums/collection -H "Authorization: Bearer $API_KEY" -H "Content-Type: application/vnd.api+json" -d '{"data":{"type":"album","attributes":{"artist_name":"Kraftwerk","title":"Autobahn","copy":{"format":"LP"}}}}'
```

Jede Anfrage braucht einen API-Key (Seite „Konto“): `-H "Authorization: Bearer <Key>"`.
Ohne Key antwortet die API mit 403. Die Swagger-UI ist ohne Key lesbar; für „Try it out“
den Key über „Authorize“ eintragen.

## Betrieb

Die App läuft als Container auf einem TrueNAS-NAS hinter nginx-proxy-manager. Image
bauen, Konfiguration, Backups und Updates: [deploy/README.md](deploy/README.md).

## Dokumentation

- [AGENTS.md](AGENTS.md): Hinweise für KI-Assistenten und Mitwirkende
- [docs/adr/](docs/adr/): Architekturentscheidungen (Architecture Decision Records)
