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

- Elixir 1.20 / OTP 29, Phoenix (aktuelle Version), Ash 3.x
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

_Werden ergänzt, sobald das Projekt angelegt ist._

## Stolperfallen

- AshAuthentication hat keine eingebaute Passkey-Strategie, siehe [ADR 0005](docs/adr/0005-passkey-login.md).
- Bei `podman compose` übernimmt das externe `docker-compose` die Ausführung. Der Hinweis
  dazu in der Ausgabe ist harmlos.
