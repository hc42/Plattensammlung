# Plattensammlung

Web-Anwendung zum Erfassen und Verwalten einer privaten Schallplattensammlung.

> **Status:** Konzept steht, das Projekt wird angelegt.

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

1. Projekt anlegen (Phoenix und Ash über Igniter), Postgres über `compose.yml`
2. Domain `Records` mit Artist, Album und Copy, plus Seed-Daten
3. LiveView-Oberfläche: Liste, Suche und Filter, Detailseite, Schnellerfassung, Wunschliste
4. Import: Suche nach Artist und Titel sowie Barcode bei Discogs und MusicBrainz, Cover lokal speichern
5. Barcode-Scan mit der Kamera im Browser
6. JSON-API (AshJsonApi) mit OpenAPI-Doku
7. Login per Passkey, Magic Link als Rückfallebene
8. Extras: Statistiken, Export (JSON-LD / CSV)

## Entwicklung

_Folgt, sobald das Projekt angelegt ist._ Geplant ist:

```bash
podman compose up -d   # Postgres starten
mix setup              # Abhängigkeiten, Datenbank, Seeds
mix phx.server         # http://localhost:4000
```

## Dokumentation

- [AGENTS.md](AGENTS.md): Hinweise für KI-Assistenten und Mitwirkende
- [docs/adr/](docs/adr/): Architekturentscheidungen (Architecture Decision Records)
