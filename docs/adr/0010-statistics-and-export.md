# 0010. Statistics and export

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

The collection is to be evaluated (size, value, genres, decades, condition) and exported as a
file: as a backup, for spreadsheets and in an open format ([ADR 0006](0006-data-model.md) names
schema.org as the model).

## Decision

**Statistics**

- Generic Ash action `Album.statistics` (code interface `Records.statistics/1`, API
  `GET /api/json/albums/statistics`). It returns a map with key figures and breakdowns, so
  interface and API use the same computation.
- The database computes totals and counts (`Ash.count/2`, `Ash.sum/3`). Breakdowns (genres,
  decades, condition, artists) are counted in Elixir. For a private collection that's fast
  enough, and genre lists stay simple.
- "Purchase value" is the sum of the recorded purchase prices, not a market value.
- Presentation: key figure tiles and horizontal bars in one colour, each with category and
  value as text. The primary colour has less than 3:1 contrast against the background (checked
  with the palette validator), so values must never depend on the bar alone. Every chart is a
  real table (accessible).

**Export** (`Plattensammlung.Records.Export`, downloads under `/export/…`, signed-in only)

| Format | Content | Purpose |
|---|---|---|
| **CSV** (RFC 4180, UTF-8, `nimble_csv`) | All fields, one row per copy plus one per wishlist album, column `status` | Backup, spreadsheets |
| **JSON-LD** (schema.org) | `ItemList` of `MusicAlbum` with a `MusicRelease` per copy (`catalogNumber`, `recordLabel`, barcode as `identifier`, `sameAs` to Discogs/MusicBrainz) | Open, linkable format |

- The CSV column names are the API field names (English, `snake_case`).
- JSON-LD contains only the own collection (no wishlist) and **no private details** (price,
  purchase date, storage location, notes), so it can be passed on.

## Alternatives considered

- **Statistics with an SQL fragment using `GROUP BY`/`unnest`**: faster for very large data, but
  tied to Postgres and harder to read. Can be added later.
- **The Discogs CSV format**: doesn't fit the album/copy model and leaves out fields. Importing
  Discogs CSV remains a possible extension.
- **A chart library (e.g. Chart.js)**: unnecessary for simple bars. HTML and CSS are enough and
  work without JavaScript.

## Consequences

- New key figures are added in `Records.Statistics` and automatically appear in the API.
- Cover URLs in the JSON-LD are made absolute with the address of the request.
- Excel doesn't always open the comma-separated CSV correctly right away; importing via
  "Data → From Text/CSV" works.

## Addendum (2026-10-21)

Purchase price and storage location no longer exist ([ADR 0006](0006-data-model.md)). The
"purchase value" tile is replaced by "artists"; CSV and JSON-LD no longer contain the fields.

## Addendum (2026-10-21): drill-down

Tiles and bars are clickable and lead to the collection, filtered to the albums concerned
(`/?genre=Rock`, `/?decade=1970`, `/?artist=…`, `/?condition=very_good_plus|none`). Every
statistics entry provides a `filter` field for that; `Album.search` has the matching optional
arguments (preparation `AlbumFilters`). The folded entry "Andere" (other) is not clickable. The
whole row reacts to clicks (`phx-click` + `JS.navigate`), the link in the label serves keyboard
and screen readers.
