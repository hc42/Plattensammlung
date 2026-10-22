# 0016. Shared albums, personal copies and wishes

- **Status:** Accepted
- **Date:** 2026-10-22
- **Partly supersedes:** [ADR 0013](0013-own-collections.md) (albums with an owner)

## Context

With ADR 0013 every user had their own album records. If two users had the same album, it
existed twice, each with its own copy of the cover file. What's wanted is that albums are
shared like artists: "Abbey Road" exists once, everyone attaches their own copies or their wish
to it. No one should be able to delete an album that someone else still has in collection or
wishlist.

## Decision

- **Album** (shared, without owner): artist, title, year, genres, cover, Discogs, MusicBrainz,
  Spotify and Tidal links.
- **Copy** (personal): gets an owner (`owner`). Every signed-in user may add own copies to any
  album; only the owner changes and deletes them. Notes and purchase date stay private (field
  policy, now `owner_id == actor`).
- **Wish** (personal, new): "I'm looking for this album", at most one per user and album.
  Replaces the field `albums.wanted`.
- **From the actor's point of view:** `owned`, `copy_count` and `wanted` are calculations over
  the own copies and the own wish.
- **Adding:** `add_to_collection` and `add_to_wishlist` are generic actions
  (`Records.AddAlbum`). They reuse an existing album, found by the Discogs master ID, then the
  MusicBrainz ID, then artist and title (ignoring case). A reused album only gets missing values
  (`Album.complete`), so no one overwrites the shared data by adding an album.
- **Changing album data:** everyone who has the album in collection or wishlist (like a wiki).
  Everyone may put it on their own wishlist (`mark_wanted`).
- **Removing** (`Album.remove`): deletes the own copies and the own wish. The album itself (with
  its cover and, if applicable, its artist) is deleted as soon as no one has it any more; the
  destroy policy only allows that. Deleting the last copy individually leaves the album in the
  catalogue ("Alle Alben"); there anyone can remove it as long as no one has it.
- **Lists:** collection and wishlist show the actor's (or another user's with `owner_id`).
  "Alle Alben" is the shared catalogue; "Nicht bei mir" filters to albums without an own copy
  and without an own wish.
- **Artists** (ADR 0015): "another user has an album of theirs" now means: an album of the artist
  with a copy or wish of someone else.
- **No surrounding transaction:** cover download and link lookup run before each step's own
  transaction. If the copy of a just created album fails, the album is deleted again.
- **Migration:** copies take over the previous owner of their album, `wanted` becomes a wish,
  albums with the same artist and title are merged into the oldest one (gaps filled from the
  others). Rolling back only works while no album is shared.

## Alternatives considered

- **Changing only while the album isn't shared:** safer against changes by others, but a typo
  in the title could then no longer be fixed.
- **Uniqueness via a database index** (e.g. on artist and title): different albums can have the
  same name (Peter Gabriel's four "Peter Gabriel"), finding by IDs is more precise.
- **Keep own album records, only linked:** duplicate maintenance of covers and links.

## Consequences

- A cover someone changes changes for everyone who has the album.
- The API: `POST /albums/collection` and `/albums/wishlist` are generic routes (arguments
  directly under `data`, answer as plain JSON with `id`), `DELETE /albums/:id/mine` removes the
  own entry, `DELETE /albums/:id` only works for albums no one has. New: `/wishes`.
- "Auf meine Wunschliste" no longer copies anything; `Covers.duplicate/1` and the action
  `copy_to_wishlist` are gone.
