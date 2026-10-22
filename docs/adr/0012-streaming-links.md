# 0012. Spotify and Tidal links

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

For every album an optional Spotify and Tidal link is to be stored, automatically where
possible. In addition albums are to be added to the collection or wishlist from a Spotify link
(e.g. shared from the Spotify app or as a QR code).

The official Spotify and Tidal APIs require developer accounts with credentials,
Odesli/song.link now an API key. The "Spotify codes" (wave bars in the app) can only be decoded
through Spotify's signed-in interface.

## Decision

- `Album.spotify_album_id` and `Album.tidal_album_id` store only the IDs; the links
  (`spotify_url`, `tidal_url`) are built from them. A pasted link is reduced to the ID (change
  `NormalizeStreamingIds`), invalid links are rejected.
- **Filled in automatically** (`Lookup.StreamingLinks`, change `FillStreamingLinks`), without an
  account and only with open data, in three steps:
  1. Without a MusicBrainz ID, MusicBrainz maps the Discogs master ID to an album. This link is
     stored as well.
  2. **Wikidata**: Spotify album ID (P2205) and Tidal album ID (P4577), found via the MusicBrainz
     (P436) or Discogs ID (P1954).
  3. **MusicBrainz**: streaming links of the album's individual releases, the newest with a link
     first. This covers albums for which Wikidata has nothing (e.g. "Night Train" by The Oscar
     Peterson Trio).
  This runs on import, on matching, when the Discogs or MusicBrainz link changes, and with the
  button "Streaming-Links suchen" (`Album.find_streaming_links`). Plain editing stays offline.
- **Spotify links in the import**: the search field recognizes Spotify album links and URIs, the
  scanner also QR codes with such links. Resolved via Wikidata (Spotify ID → album), then
  MusicBrainz (URL lookup → release → album), finally Spotify's public oEmbed. That only
  provides the title, which is then searched.
- Spotify codes (wave bars) are not supported.

## Alternatives considered

- **Spotify Web API / Tidal API** with own developer accounts (client credentials): complete
  search, but needs accounts, keys and their maintenance. Can be added later as another source.
- **Odesli/song.link**: converts links between services, but now requires a key.
- **Deezer search** (no account): finds albums, but only provides Deezer links.

## Consequences

- The hit rate depends on how well Wikidata and MusicBrainz are maintained. Missing links can
  be pasted by hand at any time.
- Up to four additional requests on import or matching; the MusicBrainz limit (1/s) is handled
  by Req retries.
- The links appear in the API, the CSV and as `sameAs` in the JSON-LD.

## Addendum (2026-10-21): fallback via artist and title

For some albums Discogs has side masters (e.g. "Kind of Blue", master 886682 with all sidemen
credited) that MusicBrainz doesn't know. If MusicBrainz finds no release group for the Discogs
master, `MusicBrainz.release_group_for_name/2` searches by artist and title. Only exact matches
count (ignoring case), studio albums before compilations. The release group found is stored as
the MusicBrainz link. The fallback only applies with a Discogs link; albums entered by hand stay
offline.
