# 0015. Protect shared artists

- **Status:** Accepted
- **Date:** 2026-10-22

## Context

Artists are shared by all users ([ADR 0013](0013-own-collections.md)), so "The Beatles" doesn't
exist once per person. Their policy still dated from the time of the one shared collection:
every signed-in user could rename and delete artists. Through the API one user could have
renamed the artist for everyone else.

## Decision

- **Reading and creating** is allowed for all signed-in users. An artist is mostly created
  automatically from the album's artist name (`FindOrCreateArtist`).
- **Renaming and deleting** only while no other user has an album of this artist (policy
  `not exists(albums, owner_id != actor)`).
- **Deleting** additionally only without own albums (validation `ArtistWithoutAlbums`); the
  albums must first be deleted or assigned to another artist.
- **Cleanup:** when an artist's last album is deleted or assigned to another artist, the artist
  disappears automatically (change `RemoveOrphanedArtist`, `Records.ArtistCleanup`). At app
  start leftover artists without albums are removed (like orphaned cover files).

## Alternatives considered

- **No longer allow changing artists at all:** typos in an artist name could then only be fixed
  by moving every album.
- **Artists per user:** duplicates without benefit (see ADR 0013).

## Consequences

- A shared artist is corrected through the artist name on the own album: the album is moved,
  the old artist stays for the others.
- The startup task runs without an actor (`authorize?: false`), like the seeds.
