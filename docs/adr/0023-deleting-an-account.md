# 0023. Deleting an account

- **Status:** Accepted
- **Date:** 2026-10-23

## Context

Users could not leave: their copies, wishes, passkeys and API keys stayed until someone removed
them from the database by hand. With shared albums (ADR 0016) deleting a user also touches the
catalogue the others use.

## Decision

- **Who:** only the user themselves (`User.delete_account`, policy `id == actor`). There is no
  admin role.
- **Confirmation:** on the account page the own e-mail address has to be typed in; a CSV export
  is offered right there.
- **What goes:**
  - Every album the user has is removed from their collection and wishlist through
    `Records.remove_album/2`, exactly like "Remove" on the album page: an album no one else has
    is deleted with its cover and, if now unused, its artist. Albums others have stay unchanged.
  - API keys and all stored tokens of the user; with `require_token_presence_for_authentication?`
    this ends every session at once.
  - The user row; passkeys (and any copies or wishes left) follow by `on_delete: :delete`.
- **Order:** the albums are removed before the transaction (`remove_album` deletes cover files
  after its own commit and can't run inside another transaction); keys, tokens and the user
  are deleted in one transaction.
- The address stays in `ALLOWED_EMAILS`: signing in again creates a new, empty account.

## Alternatives considered

- **Keep albums nobody has in the catalogue:** they would stay as entries without holders that
  everyone may edit or delete (ADR 0016 addendum). Rejected for consistency with "Remove".
- **Soft delete (mark as deleted):** keeps data the user asked to be gone; no need for it here.
- **Deleting by an admin:** would need roles; out of scope.

## Consequences

- If removing an album fails, nothing is deleted from the user yet; a later attempt continues.
  If the transaction at the end fails, the albums are already removed but the user still exists.
- New data that belongs to a user needs `on_delete: :delete` or a step in `DeleteAccountData`.
