# 0019. Metriken (Prometheus) und Traces (OpenTelemetry)

- **Status:** Angenommen
- **Datum:** 2026-10-22

## Kontext

Im Betrieb fehlte jeder Einblick: wie viele Anfragen auf welche Seiten, wie schnell, wer
wie viel nutzt, erfolgreiche und fehlgeschlagene Anmeldungen, Datenbestand, Verhalten der
externen Dienste. Phoenix brachte nur Metrik-Definitionen für das LiveDashboard in der
Entwicklung mit. Ereignisse (einzelne Vorgänge mit Kontext) und Logs folgen später.

## Entscheidung

- **Metriken über `:telemetry`** (Phoenix, LiveView, Ash, Ecto, Finch für Req und eigene
  Ereignisse), gesammelt mit **Peep**, als Prometheus-Text unter `/metrics` auf einem
  **eigenen Port** (`METRICS_PORT`, auf dem NAS 9568). Nicht über den App-Endpoint, damit
  der Port nur im LAN erreichbar ist und nie über nginx-proxy-manager läuft. Ohne
  `METRICS_PORT` gibt es keinen Endpunkt.
- **Metriken** (`Plattensammlung.Metrics`):
  - HTTP: Anzahl nach Routen-Muster (`/albums/:id`), Methode, Status und Art des Clients
    (Browser-Session, API-Key, anonym); Dauer nach Route.
  - LiveView: Mounts nach View, Ereignisse nach View und Event mit Dauer.
  - Pro Benutzer: HTTP-Anfragen und LiveView-Ereignisse (Benutzer-ID; wenige Benutzer).
  - Ash-Actions nach Domain, Resource und Action, mit Dauer (gilt für Oberfläche und API).
  - Anmeldungen nach Weg (Passkey, Anmeldelink, API-Key) und Ergebnis; Anmeldelink-
    Anfragen angenommen oder vom Rate Limit abgewiesen.
  - Datenbestand jede Minute: Alben, Exemplare, Wünsche, Künstler, Benutzer, Anzahl und
    Größe der Cover-Dateien, Größe der Datenbank.
  - Externe Dienste nach Host und Status mit Dauer, Wartezeit der MusicBrainz-Drossel.
  - System: Speicher, Run Queue, Datenbankabfragen nach Tabelle.
  - **Nicht pro IP-Adresse:** jede Adresse wäre eine neue Zeitreihe. Das gehört in Logs.
- **Traces mit OpenTelemetry:** `opentelemetry_bandit` und `opentelemetry_phoenix`
  (Anfragen, LiveView), `opentelemetry_ecto` (Abfragen), `opentelemetry_ash` (Actions, als
  Ash-Tracer) und `opentelemetry_req` (externe Anfragen, ohne Trace-Header an Dritte).
  Export per OTLP/HTTP nur mit `OTEL_EXPORTER_OTLP_ENDPOINT`, sonst `traces_exporter: :none`.
  Im Release startet `opentelemetry` als `:temporary`, damit ein Tracing-Problem die App nicht
  beendet.
- **Auf dem NAS:** Prometheus, Tempo und Grafana als eigene TrueNAS-App
  (`deploy/observability/`), Grafana mit vorbereiteten Datenquellen und Dashboard.

## Betrachtete Alternativen

- **Metriken über OpenTelemetry:** in Erlang/Elixir noch experimentell; Prometheus über
  `telemetry_metrics` ist bewährt.
- **PromEx:** viele fertige Dashboards, aber deutlich mehr Abhängigkeiten und Konfiguration.
- **LiveDashboard im Betrieb:** nur Live-Werte ohne Verlauf, bräuchte eine Admin-Rolle.
- **`/metrics` am App-Endpoint mit Token:** wäre über den Proxy aus dem Internet erreichbar.

## Konsequenzen

- Neue Seiten, Actions und externe Aufrufe erscheinen ohne weiteres Zutun in Metriken und
  Traces. Neue eigene Ereignisse: in `Plattensammlung.Metrics` definieren und auslösen.
- Hohe Kardinalität vermeiden: Tags nur mit wenigen möglichen Werten (keine Pfade, IDs von
  Alben, IP-Adressen).
- Asynchrone LiveView-Arbeit (`start_async`, z. B. der Import) erscheint als eigener Trace
  ohne Verbindung zum auslösenden Event.
- Der Zähler-Stand beginnt nach jedem Neustart bei null; Prometheus rechnet das bei `rate`
  und `increase` heraus.
