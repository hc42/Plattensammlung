# Plattensammlung

Web-Anwendung zum Erfassen und Verwalten einer privaten Schallplattensammlung.

> **Status:** Sammlung, Wunschliste, Import über Discogs und MusicBrainz sowie der Barcode-Scan mit Kamera oder Foto funktionieren. Als Nächstes kommt die JSON-API.

## Ziele

- **Erfassen mit minimalem Aufwand**: Pflicht sind nur Artist und Albumtitel, alles andere ist optional
- Barcode scannen (oder nach Artist und Titel suchen), Daten und Cover von Discogs und MusicBrainz übernehmen, ohne eine Pressungsvariante auswählen zu müssen
- Schnell beantworten: „Habe ich diese Platte?“, mit Links zu Discogs
- **Wunschliste**: Alben merken, die man noch sucht. Der Scan im Plattenladen zeigt sofort „habe ich“ oder „steht auf der Wunschliste“
- Sammlung durchsuchen und filtern, z. B. nach Artist, Genre oder Jahr
- Zugriff über eine Weboberfläche **und** eine JSON-API
- Anmeldung per Passkey
- Später: Statistiken (Wert der Sammlung, Platten pro Genre), Export

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
- **Copy**: ein eigenes Exemplar. Album mit Copy = „habe ich“. Alle Pressungs- und Sammlerangaben sind optional (Label, Barcode, Zustand, Preis, Lagerort).

Details stehen in [ADR 0006](docs/adr/0006-datenmodell.md).

## Fahrplan

1. ✅ Projekt anlegen (Phoenix und Ash über Igniter), Postgres über `compose.yml`
2. ✅ Domain `Records` mit Artist, Album und Copy, plus Seed-Daten
3. ✅ LiveView-Oberfläche: Liste, Suche und Filter, Detailseite, Schnellerfassung, Wunschliste
4. ✅ Import: Suche nach Artist und Titel sowie Barcode bei Discogs und MusicBrainz, Cover lokal speichern
5. ✅ Barcode-Scan mit der Kamera im Browser (HTTPS im WLAN: [ADR 0008](docs/adr/0008-https-im-lan.md))
6. JSON-API (AshJsonApi) mit OpenAPI-Doku
7. Login per Passkey, Magic Link als Rückfallebene
8. Extras: Statistiken, Export (JSON-LD / CSV)

## Entwicklung

Voraussetzungen: Elixir 1.20 / OTP 29, Node.js (für die Scanner-Bibliothek) und Podman (mit laufender `podman machine`).

```bash
podman compose up -d   # Postgres 18 im Container starten (Port 5432, nur localhost)
mix setup              # Abhängigkeiten, Datenbank anlegen und migrieren, Assets, Seeds
mix phx.server         # App starten: http://localhost:4000
```

Optionale Umgebungsvariablen für den Import (vor `mix phx.server` setzen):

| Variable | Zweck |
|---|---|
| `DISCOGS_TOKEN` | Persönliches Token von https://www.discogs.com/settings/developers. Ohne Token wird nur MusicBrainz durchsucht. |
| `MUSICBRAINZ_CONTACT` | E-Mail oder URL, die MusicBrainz im User-Agent sehen möchte |
| `COVERS_DIR` | Ablage der heruntergeladenen Cover (Standard: `uploads/covers`, nicht im Git) |

```bash
export DISCOGS_TOKEN=dein-token
```

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

## Dokumentation

- [AGENTS.md](AGENTS.md): Hinweise für KI-Assistenten und Mitwirkende
- [docs/adr/](docs/adr/): Architekturentscheidungen (Architecture Decision Records)
