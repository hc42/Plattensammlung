# 0008. HTTPS in the local network for the camera scan

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

The barcode scan with the phone camera ([ADR 0007](0007-barcode-scan-and-import.md)) needs
`getUserMedia`, and browsers only allow that in a secure context: HTTPS or `localhost`. The
phone, however, reaches the development machine over the Wi-Fi. The app has no sign-in yet
([ADR 0005](0005-passkey-login.md)).

## Decision

- A **self-signed certificate** is created with `mix phx.gen.cert` for `localhost` and the
  Mac's mDNS name (`<LocalHostName>.local`). It lives in `priv/cert/` and is not in Git.
- HTTPS is **opt-in**: only with `LAN=1 mix phx.server` the server also listens on
  `0.0.0.0:4001` (HTTPS). HTTP on port 4000 stays limited to `127.0.0.1`.
- In addition there is **"take a photo"** (`<input type="file" capture>`). It needs no secure
  context and therefore also works without HTTPS.

## Alternatives considered

- **mkcert** (local certificate authority): no certificate warning, but the root CA would have
  to be installed on every phone and marked as trusted. Too cumbersome for a start, and mkcert
  isn't installed.
- **Tunnel service** (e.g. ngrok, Cloudflare Tunnel): a valid certificate, but the app without
  sign-in would be reachable from the internet. Rejected.
- **HTTPS always on**: the app would be open in the Wi-Fi without being asked. Rejected as long
  as there is no sign-in.

## Consequences

- On first access the phone shows a certificate warning that must be accepted once.
- With `LAN=1` the development error pages are reachable in the Wi-Fi as well. That's only fine
  in a trusted network. Since the sign-in exists, the LiveDashboard and the mailbox under
  `/dev` are reachable only from `localhost`, as the mailbox contains sign-in links.
- Passkeys don't work with the self-signed certificate in every browser
  ([ADR 0005](0005-passkey-login.md)). On the phone the magic link is needed then.
- Production (deployment) later needs a real certificate, e.g. from Let's Encrypt.
