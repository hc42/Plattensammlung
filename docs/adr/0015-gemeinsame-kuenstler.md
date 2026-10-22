# 0015. Gemeinsame Künstler schützen

- **Status:** Angenommen
- **Datum:** 2026-10-22

## Kontext

Künstler sind für alle Benutzer gemeinsam ([ADR 0013](0013-eigene-sammlungen.md)), damit
„The Beatles“ nicht für jeden doppelt existiert. Ihre Policy stammte noch aus der Zeit der
einen gemeinsamen Sammlung: Jeder Angemeldete durfte Künstler umbenennen und löschen. Über
die API hätte ein Benutzer so den Künstler aller anderen umbenennen können.

## Entscheidung

- **Lesen und Anlegen** dürfen alle Angemeldeten. Angelegt wird ein Künstler meist
  automatisch über den Albumnamen (`FindOrCreateArtist`).
- **Umbenennen und Löschen** nur, solange kein anderer Benutzer ein Album dieses Künstlers
  hat (Policy `not exists(albums, owner_id != actor)`).
- **Löschen** zusätzlich nur ohne eigene Alben (Validation `ArtistWithoutAlbums`); die
  Alben müssen vorher gelöscht oder einem anderen Künstler zugeordnet werden.
- **Aufräumen:** Wird das letzte Album eines Künstlers gelöscht oder einem anderen Künstler
  zugeordnet, verschwindet der Künstler automatisch (Change `RemoveOrphanedArtist`,
  `Records.ArtistCleanup`). Beim App-Start werden übrig gebliebene Künstler ohne Alben
  entfernt (wie verwaiste Cover-Dateien).

## Betrachtete Alternativen

- **Künstler gar nicht mehr ändern:** Tippfehler im Künstlernamen ließen sich dann nur über
  das Umhängen jedes Albums korrigieren.
- **Künstler pro Benutzer:** Dubletten ohne Nutzen (siehe ADR 0013).

## Konsequenzen

- Einen gemeinsamen Künstler korrigiert man über den Künstlernamen am eigenen Album: Das
  Album wird umgehängt, der alte Künstler bleibt für die anderen bestehen.
- Der Start-Task läuft ohne Actor (`authorize?: false`), wie die Seeds.
