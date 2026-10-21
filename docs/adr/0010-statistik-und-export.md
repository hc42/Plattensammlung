# 0010. Statistik und Export

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

Die Sammlung soll sich auswerten lassen (Umfang, Wert, Genres, Jahrzehnte, Zustand) und
als Datei herausgegeben werden können: als Backup, für Tabellenkalkulationen und in
einem offenen Format ([ADR 0006](0006-datenmodell.md) nennt schema.org als Vorbild).

## Entscheidung

**Statistik**

- Generische Ash-Action `Album.statistics` (Code Interface `Records.statistics/1`, API
  `GET /api/json/albums/statistics`). Sie liefert eine Map mit Kennzahlen und
  Aufschlüsselungen. Damit nutzen Oberfläche und API dieselbe Berechnung.
- Summen und Zählungen berechnet die Datenbank (`Ash.count/2`, `Ash.sum/3`).
  Aufschlüsselungen (Genres, Jahrzehnte, Zustand, Künstler) werden in Elixir gezählt.
  Für eine private Sammlung ist das schnell genug, und Genre-Listen bleiben einfach.
- „Kaufwert“ ist die Summe der erfassten Kaufpreise, kein Marktwert.
- Darstellung: Kennzahlen-Kacheln und horizontale Balken in einer Farbe, jeweils mit
  Kategorie und Wert als Text. Die Primärfarbe hat unter 3:1 Kontrast zum Hintergrund
  (geprüft mit dem Palette-Validator), deshalb dürfen Werte nie nur am Balken hängen.
  Jedes Diagramm ist eine echte Tabelle (barrierefrei).

**Export** (`Plattensammlung.Records.Export`, Downloads unter `/export/…`, nur angemeldet)

| Format | Inhalt | Zweck |
|---|---|---|
| **CSV** (RFC 4180, UTF-8, `nimble_csv`) | Alle Felder, eine Zeile pro Exemplar plus eine pro Wunschlisten-Album, Spalte `status` | Backup, Tabellenkalkulation |
| **JSON-LD** (schema.org) | `ItemList` von `MusicAlbum` mit `MusicRelease` je Exemplar (`catalogNumber`, `recordLabel`, Barcode als `identifier`, `sameAs` zu Discogs/MusicBrainz) | Offenes, verlinkbares Format |

- Spaltennamen im CSV entsprechen den Feldnamen der API (englisch, `snake_case`).
- JSON-LD enthält nur die eigene Sammlung (keine Wunschliste) und **keine privaten
  Angaben** (Preis, Kaufdatum, Lagerort, Notizen), damit man es weitergeben kann.

## Betrachtete Alternativen

- **Statistik per SQL-Fragment mit `GROUP BY`/`unnest`**: schneller bei sehr großen
  Datenmengen, aber an Postgres gebunden und schwerer zu lesen. Kann man nachrüsten.
- **Discogs-CSV-Format**: passt nicht zum Album/Exemplar-Modell und lässt Felder weg.
  Ein Import von Discogs-CSV bleibt eine mögliche Erweiterung.
- **Diagramm-Bibliothek (z. B. Chart.js)**: für einfache Balken unnötig. HTML und CSS
  reichen und funktionieren ohne JavaScript.

## Konsequenzen

- Neue Kennzahlen kommen in `Records.Statistics` hinzu und erscheinen automatisch auch
  in der API.
- Cover-URLs im JSON-LD werden mit der Adresse der Anfrage absolut gemacht.
- Excel öffnet die CSV mit Komma-Trennung nicht immer direkt richtig; der Import über
  „Daten → Aus Text/CSV“ funktioniert.

## Nachtrag (2026-10-21)

Kaufpreis und Lagerort gibt es nicht mehr ([ADR 0006](0006-datenmodell.md)). Die Kachel
„Kaufwert“ ist durch „Künstler“ ersetzt; CSV und JSON-LD enthalten die Felder nicht mehr.

## Nachtrag (2026-10-21): Drill-down

Kacheln und Balken sind klickbar und führen zur Sammlung, gefiltert auf die betroffenen
Alben (`/?genre=Rock`, `/?decade=1970`, `/?artist=…`, `/?condition=very_good_plus|none`).
Jeder Statistik-Eintrag liefert dafür ein `filter`-Feld; `Album.search` hat die passenden
optionalen Argumente (Preparation `AlbumFilters`). Der zusammengefasste Eintrag „Andere“ ist
nicht klickbar. Die ganze Zeile reagiert auf Klicks (`phx-click` + `JS.navigate`), der Link in
der Beschriftung dient Tastatur und Screenreadern.
