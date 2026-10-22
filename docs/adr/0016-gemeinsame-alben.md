# 0016. Gemeinsame Alben, persönliche Exemplare und Wünsche

- **Status:** Angenommen
- **Datum:** 2026-10-22
- **Ersetzt teilweise:** [ADR 0013](0013-eigene-sammlungen.md) (Alben mit Besitzer)

## Kontext

Mit ADR 0013 hatte jeder Benutzer eigene Album-Datensätze. Hatten zwei Benutzer dasselbe
Album, gab es es doppelt, mit eigener Kopie der Cover-Datei. Gewünscht ist, dass Alben wie
Künstler gemeinsam sind: „Abbey Road“ gibt es einmal, jeder hängt seine eigenen Exemplare
oder seinen Wunsch daran. Niemand soll ein Album löschen können, das ein anderer noch in
Sammlung oder Wunschliste hat.

## Entscheidung

- **Album** (gemeinsam, ohne Besitzer): Künstler, Titel, Jahr, Genres, Cover, Discogs-,
  MusicBrainz-, Spotify- und Tidal-Verknüpfung.
- **Exemplar** (`Copy`, persönlich): bekommt einen Besitzer (`owner`). Jeder Angemeldete
  darf eigene Exemplare zu jedem Album anlegen; ändern und löschen nur der Besitzer.
  Notizen und Kaufdatum bleiben privat (Field Policy, jetzt `owner_id == actor`).
- **Wunsch** (`Wish`, persönlich, neu): „Ich suche dieses Album“, höchstens einer pro
  Benutzer und Album. Ersetzt das Feld `albums.wanted`.
- **Aus Sicht des Actors:** `owned`, `copy_count` und `wanted` sind Berechnungen über die
  eigenen Exemplare bzw. den eigenen Wunsch.
- **Erfassen:** `add_to_collection` und `add_to_wishlist` sind generische Actions
  (`Records.AddAlbum`). Sie verwenden ein vorhandenes Album wieder, gefunden über die
  Discogs-Master-ID, dann die MusicBrainz-ID, dann Künstler und Titel (ohne Groß- und
  Kleinschreibung). Ein wiederverwendetes Album bekommt nur fehlende Werte
  (`Album.complete`), sodass niemand beim Erfassen die gemeinsamen Daten überschreibt.
- **Ändern der Albumdaten:** jeder, der das Album in Sammlung oder Wunschliste hat (wie in
  einem Wiki). Auf die eigene Wunschliste setzen (`mark_wanted`) darf jeder.
- **Entfernen** (`Album.remove`): löscht die eigenen Exemplare und den eigenen Wunsch. Das
  Album selbst (mit Cover und gegebenenfalls Künstler) wird gelöscht, sobald niemand es mehr
  hat; die Destroy-Policy erlaubt nur das. Wer das letzte Exemplar einzeln löscht, lässt das
  Album im Katalog stehen („Alle Alben“); dort kann es jeder entfernen, solange es niemand hat.
- **Listen:** Sammlung und Wunschliste zeigen die des Actors (oder mit `owner_id` die eines
  anderen). „Alle Alben“ ist der gemeinsame Katalog; „Nicht bei mir“ filtert auf Alben ohne
  eigenes Exemplar und ohne eigenen Wunsch.
- **Künstler** (ADR 0015): „hat ein anderer Benutzer ein Album davon“ heißt jetzt: ein
  Album des Künstlers mit Exemplar oder Wunsch eines anderen.
- **Ohne umgebende Transaktion:** Cover-Download und Linksuche laufen vor der Transaktion
  des jeweiligen Schritts. Scheitert das Exemplar eines gerade angelegten Albums, wird das
  Album wieder gelöscht.
- **Migration:** Exemplare übernehmen den bisherigen Besitzer ihres Albums, `wanted` wird zu
  einem Wunsch, Alben mit gleichem Künstler und Titel werden zum ältesten zusammengeführt
  (Lücken aus den anderen ergänzt). Zurück geht es nur, solange kein Album geteilt ist.

## Betrachtete Alternativen

- **Ändern nur, solange das Album ungeteilt ist:** sicherer gegen Änderungen anderer, aber
  ein Tippfehler im Titel ließe sich dann nicht mehr korrigieren.
- **Eindeutigkeit per Datenbank-Index** (z. B. auf Künstler und Titel): verschiedene Alben
  können gleich heißen (Peter Gabriels vier „Peter Gabriel“), die Suche über IDs ist genauer.
- **Weiter eigene Album-Datensätze, nur verknüpft:** doppelte Pflege von Cover und Links.

## Konsequenzen

- Ein Cover, das jemand ändert, ändert sich für alle, die das Album haben.
- Die API: `POST /albums/collection` und `/albums/wishlist` sind generische Routen (Argumente
  direkt unter `data`, Antwort als einfaches JSON mit `id`), `DELETE /albums/:id/mine`
  entfernt das eigene, `DELETE /albums/:id` geht nur bei Alben, die niemand hat. Neu:
  `/wishes`.
- „Auf meine Wunschliste“ kopiert nichts mehr; `Covers.duplicate/1` und die Action
  `copy_to_wishlist` sind entfallen.
