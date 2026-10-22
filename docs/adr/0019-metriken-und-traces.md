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

## Nachtrag (2026-10-22): Alarme und Trace-Dashboard

- **Alarme mit Grafana Alerting**, als Dateien im Repo
  (`deploy/observability/grafana/provisioning/alerting/`), lokal und auf dem NAS gleich.
  Benachrichtigung per E-Mail über den SMTP-Zugang der App (`grafana.env`, `ALERT_EMAIL`).
  Regeln mit Startwerten: App nicht erreichbar (5 min), mehr als 5 Anfragen/s (10 min), mehr
  als 1 anonyme Anfrage/s (10 min), mehr als 10 fehlgeschlagene Anmeldungen pro Stunde,
  gedrosselte Anmeldelinks, mehr als 5 % Serverfehler (10 min), p95 über 2 s ohne Import
  und Abgleich (15 min), mehr als 20 % Fehler bei einem externen Dienst (15 min).
  Nur „App nicht erreichbar“ wertet fehlende Daten als Alarm.
- **Zähler starten bei 0:** Prometheus erkennt einen Anstieg erst, wenn die Zeitreihe schon
  existiert. Die Anmelde-Zähler sind deshalb Summen, die beim Start für alle Kombinationen
  mit 0 angelegt werden (`Metrics.init_counters/0`); sonst hätte der Alarm für
  fehlgeschlagene Anmeldungen nie ausgelöst (im Test nachgestellt).
- **Tempo Metrics Generator:** Span-Metriken und Service-Grafik (App, Datenbank, externe
  Dienste) aus den Traces, per Remote Write in Prometheus. Dashboard „Plattensammlung –
  Traces“ mit Service-Grafik, Kennzahlen pro Span und TraceQL-Listen (langsame Anfragen,
  Fehler, langsame externe Abfragen, Ash-Actions, Datenbankabfragen). Tempo 2.8 kennt
  `span:parent` noch nicht; Wurzel-Spans werden über `nestedSetParent < 0` gefunden.

## Nachtrag (2026-10-22): Speicherbedarf

- Traces bleiben 14 Tage in Tempo (`block_retention`), geschätzt rund 100 MB.
- Prometheus auf dem NAS: 90 Tage **oder** 2 GB, was zuerst erreicht ist
  (`--storage.tsdb.retention.size`), Abfrage alle 30 statt 15 Sekunden. Lokal 7 Tage oder 500 MB.
- Die Minutenmessung des Datenbestands erzeugt keine Traces mehr (nicht gesampelter
  Eltern-Span in `Metrics.measure_data/0`); sie war ohne jede Nutzung die größte Quelle von
  Spans. Ihre Metriken bleiben.
