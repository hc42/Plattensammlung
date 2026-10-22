# 0024. Merging duplicate albums

- **Status:** Accepted
- **Date:** 2026-10-23

## Context

Albums are shared catalogue entries (ADR 0016). Adding reuses an existing album with the same
Discogs or MusicBrainz id or the same artist and title, but differently spelled titles
("Tago Mago" and "Tago Mago (Remaster)") or imports from different sources still create two
entries for one record. Their copies and wishes are then split, statistics count the record
twice, and fixing it meant deleting and re-adding by hand.

## Decision

- A generic action `Album.merge(source_id, target_id)` (`Records.merge_albums/2`), implemented in
  `Records.MergeAlbums`. In one transaction:
  - all copies of the source, of every user, move to the target (`Copy.move`);
  - a wish moves too (`Wish.move`), unless its owner already has the target in collection or
    wishlist; wishes on the target of owners who now have a copy are deleted, as adding a copy
    ends the wish;
  - empty fields of the target are filled from the source (`Album.absorb`, like
    `Album.complete`); the cover only if the target has none;
  - the source is deleted, with its artist if they have no album left.
  The source's cover file is deleted after the commit, unless it moved to the target.
- **Who may merge:** whoever has one of the two albums in collection or wishlist, or anyone if
  no one has either (policy check `Checks.CanMerge`). Typical case: two collectors created the
  same record independently; either of them may bring them together. The other collectors'
  copies and wishes move along unchanged; nothing of theirs is lost.
- The steps across users (`Copy.move`, `Wish.move`, `Album.absorb`) are internal actions without
  a policy of their own; they only run inside the merge, after the check.
- **Page** `/albums/:id/merge` (album page, "⋯" menu): search the catalogue (prefilled with the
  title), choose the other entry, pick which one to keep (default: the one with a cover, else the
  one more collectors have).
- Not in the JSON API for now.

## Alternatives considered

- **Only who may edit both albums:** stricter, but in the typical case (each collector has one of
  the two) no one could merge.
- **Every signed-in user:** simplest, but strangers could merge albums only others have.
- **Automatic duplicate detection:** fuzzy matching of titles and artists is error-prone
  (live albums, remasters, deluxe editions are different records for some collectors). Merging
  stays a deliberate decision.

## Consequences

- A merge can't be undone; the page asks for confirmation.
- New per-user data that points to an album must be moved in `MergeAlbums` too.
- Other collectors may find their copy under a slightly different title afterwards; the
  remaining album keeps its title and artist.
