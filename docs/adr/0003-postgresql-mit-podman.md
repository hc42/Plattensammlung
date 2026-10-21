# 0003. PostgreSQL in Podman per Compose

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

Ash braucht einen Datenlayer. Auf dem Entwicklungsrechner (macOS) gibt es kein lokales
Postgres, aber Podman und Apple Container.

## Entscheidung

- **PostgreSQL** mit **AshPostgres** als Datenlayer.
- Postgres läuft als Container mit **Podman**, gesteuert über eine `compose.yml` im
  Projekt (`podman compose up -d`). Die Daten liegen in einem benannten Volume.
- Die Phoenix-App läuft während der Entwicklung direkt auf dem Mac, damit Kompilieren
  und Live-Reload schnell bleiben.

## Betrachtete Alternativen

- **SQLite (AshSqlite)**: keine Installation nötig, aber weniger Funktionen
  (Aggregate, Volltext- und Trigramm-Suche, Migrationen).
- **DuckDB**: für Auswertungen (OLAP) gebaut, nicht für eine App mit vielen einzelnen
  Schreibzugriffen. Es gibt keinen Ash-Datenlayer.
- **Apple Container**: funktioniert, ist aber noch jung und ohne Compose-Unterstützung.

## Konsequenzen

- Voller Ash-Funktionsumfang, z. B. unscharfe Suche mit `pg_trgm` und Aggregate in der
  Datenbank.
- Vor dem Entwickeln muss der Container laufen.
