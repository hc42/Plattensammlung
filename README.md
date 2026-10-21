# Plattensammlung

Web-Anwendung zum Erfassen und Verwalten einer privaten Schallplattensammlung.

> **Status:** Konzeptphase. Es gibt noch keinen Code. Das Datenmodell wird gerade
> besprochen (siehe [ADR 0006](docs/adr/0006-datenmodell.md)).

## Ziele

- Schallplatten schnell erfassen: Artist, Label, Pressung, Zustand, Kaufinfos, Lagerort
- Sammlung durchsuchen und filtern, z. B. nach Artist, Genre, Jahr oder Regal
- Mehrere Exemplare derselben Pressung unterscheiden
- Zugriff über eine Weboberfläche **und** eine JSON-API
- Anmeldung per Passkey
- Später: Cover-Bilder, Statistiken (Wert der Sammlung, Platten pro Genre), Import aus Discogs

## Technik

| Bereich | Wahl | Entscheidung |
|---|---|---|
| Sprache / Web | Elixir, Phoenix | [ADR 0002](docs/adr/0002-elixir-phoenix-ash.md) |
| Anwendungs-Framework | Ash (AshPostgres, AshPhoenix) | [ADR 0002](docs/adr/0002-elixir-phoenix-ash.md) |
| Datenbank | PostgreSQL in Podman (Compose) | [ADR 0003](docs/adr/0003-postgresql-mit-podman.md) |
| Oberfläche | Phoenix LiveView und AshJsonApi | [ADR 0004](docs/adr/0004-liveview-und-json-api.md) |
| Login | AshAuthentication, Passkeys über `wax_`, Magic Link als Rückfallebene | [ADR 0005](docs/adr/0005-passkey-login.md) |

## Datenmodell (Entwurf)

```
Artist ──< Release >── Label
              │
              ├──< Copy    (eigene Exemplare: Zustand, Preis, Lagerort)
              └──< Track   (optional: Seite/Position, Titel, Dauer)
```

- **Release**: eine bestimmte Veröffentlichung oder Pressung (Titel, Katalognummer, Jahr, Format).
- **Copy**: ein konkretes Exemplar, das man besitzt (Zustand, Kaufdatum, Preis, Lagerort).

Details und offene Fragen stehen in [ADR 0006](docs/adr/0006-datenmodell.md).

## Fahrplan

1. Projekt anlegen (Phoenix und Ash über Igniter), Postgres über `compose.yml`
2. Domain `Records` mit Artist, Label, Release, Copy und Track, plus Seed-Daten
3. LiveView-Oberfläche: Liste, Suche und Filter, Detailseiten, Formulare
4. JSON-API (AshJsonApi) mit OpenAPI-Doku
5. Login per Passkey, Magic Link als Rückfallebene
6. Extras: Cover-Upload, Statistiken, Discogs-Import

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
