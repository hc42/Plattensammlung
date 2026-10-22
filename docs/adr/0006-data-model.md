# 0006. Data model of the collection

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

Most important requirement: **capturing must take little effort.** The central question is
"Do I have this record?", answered by **artist, album and possibly cover**. Pressing details
are secondary. Discogs' choice between many variants of an album feels overwhelming and is to
be avoided.

So only the basics are required, everything else is optional and filled in automatically
where possible (barcode scan or import, see [ADR 0007](0007-barcode-scan-and-import.md)).

## Decision

The **album** is at the centre, not the pressing. Ash domain `Plattensammlung.Records`:

```
Artist ──< Album ──< Copy
```

| Resource | Meaning | Required | Optional |
|---|---|---|---|
| **Artist** | Artist or band | Name | Sort name ("Beatles, The"), Discogs ID |
| **Album** | The work, independent of the pressing | Title, artist | Year of release, cover, genres, `wanted` (wishlist), Discogs master ID, MusicBrainz ID |
| **Copy** | An own copy | Album | Pressing details (label, catalogue number, barcode, country, year, format, Discogs release ID), condition, purchase date and price, storage location, notes |

- **"Do I have the record?"** means: there is at least one copy of this album. This is
  computed as an Ash aggregate (`owned?` / `copy_count`), not stored.
- **Wishlist** (in the first version): a field `wanted` (yes/no) on the album. So an album can
  also exist *without* a copy, as a wish. When a copy is added, `wanted` is reset
  automatically (Ash change). An explicit field instead of "album without copy = wish" keeps a
  sold album from ending up on the wishlist by accident.
- The barcode scan also works in a record shop: "Have it already" / "On the wishlist" /
  "Add now: to the collection or to the wishlist".
- Capturing creates **album and copy in one step**. The split is invisible to the user until
  they add a second pressing.
- **One artist per album.** Compilations and collaborations get an artist such as
  "Various Artists" or "Artist A & Artist B", as Discogs delivers it.
- **Genres** as a simple list of tags on the album, filled in automatically on import.
- **Discogs links** are built from the stored IDs (`discogs.com/master/<id>`,
  `discogs.com/release/<id>`).
- Condition (if given) on the Goldmine scale: M, NM, VG+, VG, G+, G, F, P.

### Following standards

There is no single binding exchange format for record collections. There are, however,
established models that terms, IDs and export follow:

| Standard | What it is | Use here |
|---|---|---|
| **FRBR** (library science) | Work → expression → manifestation → **item** | Conceptual basis: album ≈ work, pressing = manifestation, copy = item |
| **MusicBrainz data model** | Open de-facto standard: *release group* → *release* → *medium* → *track* | **The album corresponds to the release group**, the copy's pressing details to a *release*. MBIDs are stored. |
| **Discogs** | *Master* → *release* | Album = master, pressing = release. IDs are stored for links. The collection CSV export is a possible import format. |
| **schema.org** `MusicAlbum` / `MusicRelease` | Web vocabulary (JSON-LD) | Model for field names and for a later JSON-LD export (`releaseOf`, `catalogNumber`, `recordLabel`, `musicReleaseFormat: VinylFormat`) |
| **GTIN (EAN/UPC)** | Barcode standard | Field `barcode` on the copy, key for the import |
| **Goldmine grading** | Common condition standard in the trade | Scale for the condition of record and sleeve |
| DDEX ERN | Format of digital distribution | Too extensive, not used |

Consequence: the own terms stay simple (album, copy), but map unambiguously to MusicBrainz
and Discogs. Import, matching and a later export work without restructuring.

## Alternatives considered

- **The release (pressing) at the centre**, as Discogs does it: more precise, but every entry
  forces choosing the variant. Rejected.
- **A single "record" table**: even simpler, but several copies and the wishlist would need
  duplicate data.
- **Several artists per album (many-to-many)**: more precise, but more work in UI and import.
  Can be added later.
- **Tracks, labels as their own resource, a storage location hierarchy**: not needed for now.

## Settled questions

- **Wishlist:** yes, already in the first version (field `wanted` on the album, see above).
- **Lent/sold status on the copy:** not needed. A sold record's copy is deleted.

## Consequences

- Fast capture: artist and title are enough for an entry.
- Pressing details are possible but never required.
- Missing data is fetched by the import, not typed by hand.

## Addendum (2026-10-21)

- **Storage location and purchase price removed:** not needed. The columns were dropped by a
  migration, and with them the "purchase value" in the statistics
  ([ADR 0010](0010-statistics-and-export.md)).
- **Album status "unassigned":** an album without a copy and without `wanted` (e.g. after
  deleting the last copy) stays and appears in the "all albums" view (`/albums`, filter
  `?show=unassigned`; search with status `:other`).
- **Format as a list:** `Copy.format` is a list of tags (`["Vinyl", "LP", "Album"]`), as Discogs
  delivers it. Existing texts were split at ", " by the migration.
- **Against spelling variants:** genres and format (several tags) as well as label and country
  (exactly one tag) are entered through a tag input with suggestions from the collection;
  equal values in a different spelling take over the existing one.

## Addendum (2026-10-22): limits for input

Since collections are visible to others ([ADR 0013](0013-own-collections.md)), the fields have
fixed limits (Ash `constraints`, no migration):

| Field | Limit |
|---|---|
| Album title, artist name, sort name | 200 characters |
| Label, catalogue number, country | 100 characters |
| Notes | 2000 characters |
| Genres, format | at most 20 tags of 50 characters each |
| Year of release and pressing year | 1900–2100 |
| Discogs IDs | from 1 |
| Barcode | spaces and dashes are removed, then 8–14 digits (EAN/UPC) |
| Search terms (list, import, matching) | 200 characters |

Ash counts characters as Unicode code points, like Postgres. The database is UTF-8 and stores
all characters including emojis (unlike MySQL's `utf8` there is no 3-byte limit). A composed
emoji such as 👨‍👩‍👧 counts as five code points. The forms set matching `maxlength`
attributes; browsers count UTF-16 units there, an emoji twice, so the interface never allows
more than the resource.
