# 0012. Spotify- und Tidal-Verknüpfungen

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

Zu jedem Album sollen optional ein Spotify- und ein Tidal-Link gespeichert werden,
möglichst automatisch. Außerdem sollen sich Alben über einen Spotify-Link (z. B. aus der
Spotify-App geteilt oder als QR-Code) zur Sammlung oder Wunschliste hinzufügen lassen.

Die offiziellen APIs von Spotify und Tidal verlangen Entwicklerkonten mit Zugangsdaten,
Odesli/song.link inzwischen einen API-Schlüssel. Die „Spotify-Codes“ (Wellenbalken in
der App) lassen sich nur über Spotifys angemeldete Schnittstelle entschlüsseln.

## Entscheidung

- `Album.spotify_album_id` und `Album.tidal_album_id` speichern nur die IDs, daraus
  entstehen die Links (`spotify_url`, `tidal_url`). Ein eingefügter Link wird auf die ID
  reduziert (Change `NormalizeStreamingIds`), ungültige Links werden abgelehnt.
- **Automatisch befüllen** (`Lookup.StreamingLinks`, Change `FillStreamingLinks`), ohne
  Konto und nur mit offenen Daten, in drei Schritten:
  1. Fehlt die MusicBrainz-ID, ordnet MusicBrainz die Discogs-Master-ID einem Album zu.
     Diese Verknüpfung wird gleich mitgespeichert.
  2. **Wikidata**: Spotify-Album-ID (P2205) und Tidal-Album-ID (P4577), gefunden über
     MusicBrainz- (P436) oder Discogs-ID (P1954).
  3. **MusicBrainz**: Streaming-Links der einzelnen Veröffentlichungen des Albums, die
     neueste mit Link zuerst. Das deckt Alben ab, bei denen Wikidata nichts hat (z. B.
     „Night Train“ von The Oscar Peterson Trio).
  Ausgelöst wird das beim Import, beim Abgleich, wenn sich die Discogs- oder
  MusicBrainz-Verknüpfung ändert, und per Button „Streaming-Links suchen“
  (`Album.find_streaming_links`). Normales Bearbeiten bleibt offline.
- **Spotify-Links im Import**: Das Suchfeld erkennt Spotify-Album-Links und -URIs, der
  Scanner auch QR-Codes mit solchen Links. Auflösung: Wikidata (Spotify-ID → Album), dann
  MusicBrainz (URL-Lookup → Veröffentlichung → Album), zuletzt Spotifys öffentliches
  oEmbed. Das liefert nur den Titel, der dann gesucht wird.
- Spotify-Codes (Wellenbalken) werden nicht unterstützt.

## Betrachtete Alternativen

- **Spotify Web API / Tidal API** mit eigenen Entwicklerkonten (Client Credentials):
  vollständige Suche, aber Konten, Schlüssel und deren Pflege nötig. Kann später als
  weitere Quelle ergänzt werden.
- **Odesli/song.link**: wandelt Links zwischen Diensten um, verlangt aber inzwischen einen
  Schlüssel.
- **Deezer-Suche** (ohne Konto): findet Alben, liefert aber nur Deezer-Links.

## Konsequenzen

- Die Trefferquote hängt von der Pflege in Wikidata und MusicBrainz ab. Fehlende Links
  lassen sich jederzeit von Hand einfügen.
- Bis zu vier zusätzliche Anfragen beim Import oder Abgleich; MusicBrainz-Limit (1/s)
  wird über Req-Retries abgefangen.
- Die Links erscheinen in API, CSV und als `sameAs` im JSON-LD.

## Nachtrag (2026-10-21): Rückfall über Künstler und Titel

Discogs hat zu manchen Alben Neben-Master (z. B. „Kind of Blue“, Master 886682 mit allen
Begleitmusikern), die MusicBrainz nicht kennt. Findet MusicBrainz zum Discogs-Master keine
Release Group, sucht `MusicBrainz.release_group_for_name/2` nach Künstler und Titel. Es
zählen nur genaue Treffer (ohne Groß-/Kleinschreibung), Studioalben vor Kompilationen.
Die gefundene Release Group wird als MusicBrainz-Verknüpfung gespeichert. Der Rückfall
greift nur bei vorhandenem Discogs-Link, von Hand erfasste Alben bleiben offline.
