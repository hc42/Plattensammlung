# 0014. Cover sources and Content Security Policy

- **Status:** Accepted
- **Date:** 2026-10-22

## Context

Since collections are visible to other users ([ADR 0013](0013-own-collections.md)), the app
shows one user's data in another user's browser. A review along the OWASP Top 10 found:

- **Escaping is fine:** HEEx escapes all output, there is no `raw`, the JS hooks set no
  `innerHTML`, links are built from validated IDs.
- **Access control (A01):** `cover_url` could be set through the API to a local path
  `/covers/…`, also to another user's file. Deleting the own album (or even a failing action)
  then deleted their file.
- **SSRF (A10):** the server downloaded any `http(s)` address from `cover_url`, also in the
  local network (NAS interface, router). If the answer was an image, it was retrievable
  afterwards.
- Remote URLs whose download failed stayed stored and were loaded by other users' browsers
  (tracking pixel).
- There was no Content Security Policy as a second line of defence.

## Decision

- **Allowed cover sources:** `config :plattensammlung, :cover_hosts`, currently
  `i.discogs.com`, `coverartarchive.org` and `archive.org` (each with subdomains, https only).
  `Covers.allowed_url?/1` checks this.
- **Download:** only from allowed hosts. The app follows redirects itself (at most three),
  every hop must be allowed.
- **Input:** the validation `CoverSource` allows only empty or an allowed https URL for
  `cover_url` (in `add_to_collection`, `add_to_wishlist`, `update` and after `ApplyMatch` in
  `apply_match`). Local paths are set only by the app itself: download, upload and the new
  action `copy_to_wishlist` ("Auf meine Wunschliste"), which duplicates the cover file. Own
  images come through the upload.
- **Cleanup:** if an action fails, it deletes only the file it stored itself
  (`changeset.context[:stored_cover]`), never a path from the input.
- **Content Security Policy** (`PlattensammlungWeb.Plugs.ContentSecurityPolicy`, in the
  `:browser` pipeline): scripts only from the app, the theme script in the root layout with a
  nonce per request; images from the app, `data:`/`blob:` and the cover sources; `style`
  attributes allowed, `<style>` elements not; no frames, no plugins, forms only to the app.
  `/dev` (LiveDashboard, mailbox) runs without CSP.

## Alternatives considered

- **Block private addresses instead of allowing hosts:** DNS rebinding, IPv6 and redirect tricks
  make a block list error-prone. Covers only come from the import anyway, so from known sources.
- **No longer accept `cover_url` at all:** would make taking over results from
  Discogs/MusicBrainz through the API harder.
- **CSP with `'unsafe-inline'` for scripts:** would take away most of the CSP's benefit.

## Consequences

- A new import source with own image servers must be added to `:cover_hosts`, otherwise its
  covers are rejected. The CSP takes over the list automatically.
- New inline scripts need `nonce={assigns[:csp_nonce]}`, inline `<style>` doesn't work.
- Other image URLs can no longer be entered; there is the upload for that.
