# 0006. Datenmodell der Sammlung

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

Wichtigste Anforderung: **Das Erfassen soll wenig Arbeit machen.** Im Mittelpunkt steht
die Frage „Habe ich diese Platte?“, beantwortet über **Künstler, Album und ggf. Cover**.
Pressungsdetails sind zweitrangig. Discogs’ Auswahl zwischen vielen Varianten eines
Albums wird als überfordernd empfunden und soll vermieden werden.

Pflichtfelder sind deshalb nur die Basics, alles andere ist optional und wird möglichst
automatisch befüllt (Barcode-Scan oder Import, siehe [ADR 0007](0007-barcode-scan-und-import.md)).

## Entscheidung

Im Zentrum steht das **Album**, nicht die Pressung. Ash-Domain `Plattensammlung.Records`:

```
Artist ──< Album ──< Copy
```

| Resource | Bedeutung | Pflicht | Optional |
|---|---|---|---|
| **Artist** | Künstler oder Band | Name | Sortiername („Beatles, The“), Discogs-ID |
| **Album** | Das Werk, unabhängig von der Pressung | Titel, Artist | Erscheinungsjahr, Cover, Genres, `wanted` (Wunschliste), Discogs-Master-ID, MusicBrainz-ID |
| **Copy** | Ein eigenes Exemplar | Album | Pressungsangaben (Label, Katalognummer, Barcode, Land, Jahr, Format, Discogs-Release-ID), Zustand, Kaufdatum und -preis, Lagerort, Notizen |

- **„Habe ich die Platte?“** heißt: Es gibt zu diesem Album mindestens eine Copy.
  Das wird als Ash-Aggregate (`owned?` / `copy_count`) berechnet, nicht gespeichert.
- **Wunschliste** (in der ersten Version): ein Feld `wanted` (ja/nein) am Album. Ein Album
  kann also auch *ohne* Copy existieren, als Wunsch. Wird eine Copy angelegt, wird
  `wanted` automatisch zurückgesetzt (Ash Change). Ein explizites Feld statt „Album ohne
  Copy = Wunsch“ verhindert, dass ein verkauftes Album versehentlich auf der Wunschliste
  landet.
- Der Barcode-Scan funktioniert auch im Plattenladen: „Habe ich schon“ / „Steht auf der
  Wunschliste“ / „Jetzt hinzufügen: zur Sammlung oder zur Wunschliste“.
- Beim Erfassen werden **Album und Copy in einem Schritt** angelegt. Die Trennung ist für
  den Benutzer unsichtbar, solange er keine zweite Pressung erfasst.
- **Ein Artist pro Album.** Sampler und Kollaborationen bekommen einen Artist wie
  „Various Artists“ oder „Artist A & Artist B“, so wie Discogs ihn liefert.
- **Genres** als einfache Liste von Schlagwörtern am Album, beim Import automatisch befüllt.
- **Discogs-Links** werden aus den gespeicherten IDs erzeugt
  (`discogs.com/master/<id>`, `discogs.com/release/<id>`).
- Zustand (falls angegeben) nach Goldmine-Skala: M, NM, VG+, VG, G+, G, F, P.

### Anlehnung an Standards

Ein einziges verbindliches Austauschformat für Plattensammlungen gibt es nicht. Es gibt
aber etablierte Modelle, an denen sich Begriffe, IDs und Export ausrichten:

| Standard | Was er ist | Verwendung hier |
|---|---|---|
| **FRBR** (Bibliothekswesen) | Werk → Ausprägung → Manifestation → **Exemplar** | Begriffliche Grundlage: Album ≈ Werk, Pressung = Manifestation, Copy = Exemplar |
| **MusicBrainz-Datenmodell** | Offener De-facto-Standard: *Release Group* → *Release* → *Medium* → *Track* | **Album entspricht der Release Group**, die Pressungsangaben der Copy entsprechen einem *Release*. MBIDs werden gespeichert. |
| **Discogs** | *Master* → *Release* | Album = Master, Pressung = Release. IDs werden für Links gespeichert. Collection-CSV-Export als mögliches Importformat. |
| **schema.org** `MusicAlbum` / `MusicRelease` | Web-Vokabular (JSON-LD) | Vorbild für Feldnamen und für einen späteren JSON-LD-Export (`releaseOf`, `catalogNumber`, `recordLabel`, `musicReleaseFormat: VinylFormat`) |
| **GTIN (EAN/UPC)** | Barcode-Standard | Feld `barcode` an der Copy, Schlüssel für den Import |
| **Goldmine Grading** | Branchenüblicher Zustandsstandard | Skala für den Zustand von Platte und Hülle |
| DDEX ERN | Format des Digitalvertriebs | Zu umfangreich, nicht verwendet |

Konsequenz: Die eigenen Begriffe bleiben einfach (Album, Copy), sind aber eindeutig auf
MusicBrainz und Discogs abbildbar. Dadurch funktionieren Import, Abgleich und ein
späterer Export ohne Umbau.

## Betrachtete Alternativen

- **Release (Pressung) im Zentrum**, wie Discogs es macht: genauer, aber jede Erfassung
  zwingt zur Auswahl der Variante. Verworfen.
- **Eine einzige Tabelle „Platte“**: noch einfacher, aber für mehrere Exemplare und die
  Wunschliste müssten Daten doppelt eingetragen werden.
- **Mehrere Artists pro Album (viele-zu-viele)**: genauer, aber aufwendiger in UI und
  Import. Kann später ergänzt werden.
- **Tracks, Labels als eigene Resource, Lagerort-Hierarchie**: vorerst nicht nötig.

## Geklärte Fragen

- **Wunschliste:** ja, schon in der ersten Version (Feld `wanted` am Album, siehe oben).
- **Status verliehen/verkauft an der Copy:** nicht benötigt. Eine verkaufte Platte wird
  als Copy gelöscht.

## Konsequenzen

- Schnelles Erfassen: Für einen Eintrag reichen Artist und Titel.
- Pressungsdetails sind möglich, werden aber nie verlangt.
- Fehlende Daten werden über den Import nachgeladen, nicht von Hand eingetippt.
