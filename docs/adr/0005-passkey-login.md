# 0005. Sign-in with passkeys

- **Status:** Accepted (implemented on 2026-10-21)
- **Date:** 2026-10-21

## Context

Signing in is to happen with a **passkey** (WebAuthn/FIDO2). AshAuthentication (version 4.15)
comes with strategies for password, magic link, API keys, OAuth2 and more, but **no passkey
strategy**. The JSON API ([ADR 0009](0009-json-api-design.md)) also needs authentication. The
app manages a private collection; only a few, known people are to have access.

## Decision

- **AshAuthentication** (domain `Plattensammlung.Accounts`) manages `User`, sessions and
  tokens. Strategies: **magic link** and **API key**. There are no passwords.
- **Passkeys** are built in the project, with the library **`wax_`**:
  - Resource `Passkey` (credential ID, public key as COSE key, sign count, name, last used),
    belongs to a `User`.
  - `Accounts.WebAuthn` wraps the protocol (create the challenge, verify the response).
  - `PasskeyController` provides four JSON endpoints under `/auth/passkey/`. Between the two
    requests the challenge is kept in the session and is valid only once.
  - JS hooks `PasskeySignIn` and `PasskeyRegister` call `navigator.credentials.get/create`.
  - *Discoverable credentials*: signing in needs no e-mail address, the device offers the
    matching passkeys.
  - Origin and RP ID are derived from the current request, so `localhost` and `<name>.local`
    work.
- **Magic link** (e-mail) as fallback and for the first sign-in. The link points to the
  address it was requested from. Locally the e-mails land in the Swoosh mailbox
  `/dev/mailbox` (reachable only from `localhost`).
- **Allow list:** only addresses from `ALLOWED_EMAILS` get a link and may sign in (validation
  on the magic link sign-in, check on the passkey sign-in). The sign-in page doesn't reveal
  whether an address is allowed.
- **API:** `Authorization: Bearer <API key>`. Keys are created on the account page (valid for
  30 days or 1 year), stored only as a hash and shown once.
- **Authorization with Ash policies:** all Records resources require an actor
  (`actor_present()`, `access_type :strict`). There is *one* shared collection for all
  signed-in users. Passkeys and API keys are visible only to their owner.

## Alternatives considered

- **`webauthn_components`**: ready-made LiveView components, but tied to Ecto instead of Ash.
- **Passkey sign-in through a LiveView** instead of a controller: a LiveView can't set session
  cookies. That would need a detour via a short-lived token and a redirect. The controller is
  more direct.
- **Only magic link or password**: simpler, but not what was asked for (passkeys).
- **Open registration**: without an allow list anyone on the network could create an account.

## Consequences

- WebAuthn requires a secure context: `localhost` always works. With the self-signed
  certificate from [ADR 0008](0008-https-in-the-lan.md) some browsers refuse passkeys, Chrome
  for example on certificate errors. On the phone the magic link remains.
- A passkey only works for the host name it was created on (`localhost` or `<name>.local`).
- `ALLOWED_EMAILS` must be set, otherwise no one can sign in.
- All calls to the `Records` domain need `actor:` (or deliberately `authorize?: false` in seeds).
- For production, real mail delivery (e.g. SMTP) and a real certificate are still missing.

## Addendum (2026-10-21)

The "one shared collection for all signed-in users" is replaced by an own collection per user
that all others may read ([ADR 0013](0013-own-collections.md)).
