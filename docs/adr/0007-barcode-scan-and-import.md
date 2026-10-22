# 0007. Barcode scan and import from Discogs and MusicBrainz

- **Status:** Accepted (implemented on 2026-10-21)
- **Date:** 2026-10-21

## Context

Capturing must take little effort (see [ADR 0006](0006-data-model.md)). Ideally: scan the
barcode, and artist, title, year, genres and cover are filled in. The user must **never have to
choose between many pressing variants**.

Important observation: a **barcode already identifies a specific pressing**. From it the album
can be found automatically (Discogs "master", MusicBrainz "release group"). So there is no
choice of variant.

## Decision

**Ways to capture**, all leading to a pre-filled form that only needs confirming:

1. **Scan a barcode** with the phone or laptop camera in the browser (`BarcodeDetector` API
   where available, otherwise a JS library such as ZXing). Typing the barcode digits and USB
   hand scanners (which behave like a keyboard) work as well.
2. **Search by artist and title**, for older records without a barcode (mostly before about
   1980). Hits are shown at **album level**, not as pressings.
3. **Manually**: just artist and title.

**Flow with a barcode:**
barcode → find the pressing → find its album → take over artist, title, year of release,
genres and cover. The IDs of pressing and album are stored; links to Discogs are built from
them. If a barcode has several hits, the first one is taken automatically. The pressing details
are optional anyway.

**Data sources** behind a common Elixir behaviour (`Lookup`), so sources are interchangeable:

| Source | Access | Strengths |
|---|---|---|
| **Discogs API** | Free personal token (Discogs account → settings → developers), 60 requests/minute | Very complete for vinyl, barcode search, master/release |
| **MusicBrainz** + **Cover Art Archive** | No account, at most 1 request/second, own user agent required | Open data, covers in good quality |

Discogs is asked first, MusicBrainz serves as fallback and adds missing covers. Covers are
**stored locally**, so the collection stays complete without the external services.

HTTP calls use `Req`. The search is the generic Ash action `Album.lookup`. It returns the
embedded resource `LookupResult`, so LiveView and JSON API can use it alike. A hit is taken
over through the existing actions `add_to_collection` and `add_to_wishlist`.

### Implementation details

- One input for everything: 8–14 digits (spaces and dashes allowed) count as a barcode,
  anything else as a text search.
- Text search: Discogs searches *masters*, MusicBrainz *release groups* (mode `dismax`, finds
  artist and title together). Equal albums (artist and title normalized) appear only once,
  Discogs first because it sorts better by popularity.
- Barcode on Discogs: search the release, then load the master. The master provides the
  original year and the genres, the release the pressing details for the copy.
- If a source returns an error, the next one is asked. An error is reported only if no source
  answers.
- A barcode is also checked locally: "You already have exactly this pressing" (read action
  `Album.by_barcode`, index on `copies.barcode`).
- Cover download before the database transaction, with short timeouts (4 s connect, 8 s
  response). On errors the remote URL stays.
- The lookup runs asynchronously in the LiveView (`start_async`).
- Camera scan: JS hook `BarcodeScanner` (`assets/js/hooks/barcode_scanner.js`). It uses
  `BarcodeDetector` if the browser supports EAN/UPC, otherwise `@zxing/browser`. ZXing is loaded
  with `import()` only when needed (esbuild with `--splitting`, `app.js` as an ES module). A
  code only counts when it was read twice in a row and the check digit is correct.
- "Take a photo" as an alternative to the live camera. It works without HTTPS.
- HTTPS for the phone in the Wi-Fi: see [ADR 0008](0008-https-in-the-lan.md).

## Alternatives considered

- **Only Discogs**: simpler, but depends on an account and token.
- **Let the user pick the pressing in a dialog**: exactly what is to be avoided.

## Consequences

- The camera needs a secure context in the browser. On the Mac `localhost` is enough, **from
  the phone in the Wi-Fi HTTPS is required** (e.g. a local certificate with `mkcert` or
  `mix phx.gen.cert`).
- Safari doesn't fully support `BarcodeDetector`, so a JS library is needed as fallback.
- The Discogs token is configured as an environment variable (`DISCOGS_TOKEN`), never stored in
  the repository.
- Discogs' terms of use (attribution, rate limits) must be followed. For a private collection
  this is unproblematic.

## Addendum (2026-10-21): matching existing albums

- Generic action `Album.find_matches`: fetches linked albums directly by the stored Discogs
  master or MusicBrainz release group ID (MusicBrainz also returns the top 3 genres), otherwise
  searches by artist and title or an own search term/barcode.
- Update action `Album.apply_match` with `mode: :fill` (only empty fields) or `:overwrite`.
  Artist and title are never changed. `Records.AlbumMatch` computes the changes and so also
  provides the preview in the interface.
- Barcode hits carry pressing details: they go into a chosen copy (`copy_id`), into a new one
  (`new_copy: true`) or nowhere. "Fill" and "overwrite" apply here as well.
- The scanner is a shared component (`barcode_scanner`) for import and matching.
