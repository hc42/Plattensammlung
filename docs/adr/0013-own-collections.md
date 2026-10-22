# 0013. Own collections, visible to others

- **Status:** Accepted; albums with an owner superseded by [ADR 0016](0016-shared-albums.md)
- **Date:** 2026-10-21
- **Partly supersedes:** the "one shared collection" from [ADR 0005](0005-passkey-login.md)

## Context

So far all signed-in users shared one collection. What's wanted: everyone has their own
collection and wishlist, and the other users can look at them without needing a permission.

## Decision

- **Owner:** `Album.owner` (required), set with `relate_actor(:owner)` on creation. Copies
  belong to it through their album. **Artists** stay shared, which avoids duplicates.
- **Visibility:** all signed-in users (that is, addresses from `ALLOWED_EMAILS`) may read all
  albums and copies. Without signing in nothing is visible.
- **Changing:** only the owner. Policies: update and destroy on the album with
  `owner_id == actor`, on the copy with `album.owner_id == actor`. Only the album's owner may
  create a copy (check `AlbumOwnedByActor`).
- **Default view = own albums:** the list actions (`search`, `collection`, `wishlist`,
  `by_barcode`, `duplicates`) and the statistics show the own albums without further argument
  (preparation `ScopeToOwner`). Other collections are requested explicitly with `owner_id`,
  also through the API.
- **Display name:** `User.display_name`, set on the account page. Other users only see ID and
  name (read action `collectors` selects only these fields). The e-mail address stays private.
- **Interface:**
  - Page "Sammler" (collectors, `/collectors`) with the others' collections and wishlists
    (`/collectors/:id`, `/collectors/:id/wishlist`).
  - Other people's albums are read-only. Edit pages redirect back (`Ownership`).
  - "Auf meine Wunschliste" (to my wishlist) takes over the album data with an own copy of the
    cover file.
  - Notes and purchase date of other people's copies are not shown.
- **Existing data:** the migration assigns existing albums to the one existing user. If there
  are albums but not exactly one user, it stops with an explanation instead of guessing.

## Alternatives considered

- **Permissions per collection** (who may see what): not wanted, more effort.
- **Public read link without sign-in:** can be added later.
- **Artists per user:** leads to duplicates without visible benefit.

## Consequences

- Every query of the collection needs an actor. Without an actor the lists are no longer
  limited to an owner (only relevant for seeds and maintenance with `authorize?: false`).
- Notes and purchase date are only hidden in the interface. Through the API another signed-in
  user can read them. If they are to be really private, field policies are needed.
- The seeds create the example albums for the first address in `ALLOWED_EMAILS`.

## Addendum (2026-10-21): field policies

A copy's purchase date and notes are now private in the API as well. `Copy` has field
policies: `purchased_on` and `notes` are read only by the album's owner
(`album.owner_id == actor`), all other fields stay readable for signed-in users. Other users
get `%Ash.ForbiddenField{}` in Ash, the JSON:API leaves the fields out. The interface hides
them as before.
