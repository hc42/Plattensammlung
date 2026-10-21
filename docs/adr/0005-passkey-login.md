# 0005. Login per Passkey

- **Status:** Vorgeschlagen
- **Datum:** 2026-10-21

## Kontext

Die Anmeldung soll per **Passkey** (WebAuthn/FIDO2) erfolgen. AshAuthentication
(Version 4.15) bringt Strategien für Passwort, Magic Link, OAuth2 und weitere mit, aber
**keine Passkey-Strategie**.

## Entscheidung (Vorschlag)

- **AshAuthentication** verwaltet Benutzer, Sessions und Tokens (auch für die API).
- Passkeys werden über die Bibliothek **`wax_`** (FIDO2/WebAuthn-Server) umgesetzt:
  - Resource `Credential` (Passkey) mit Credential-ID, Public Key, Sign-Count und Name,
    gehört zu einem `User`
  - eigene Ash Actions für Registrierung und Anmeldung (Challenge erzeugen, Antwort prüfen)
  - ein kleiner JavaScript-Hook in LiveView für `navigator.credentials.create/get`
- **Magic Link** (E-Mail) als Rückfallebene für die erste Anmeldung und neue Geräte.
  Lokal werden E-Mails über `Swoosh.Adapters.Local` angezeigt.

## Betrachtete Alternativen

- **`webauthn_components`**: fertige LiveView-Komponenten, aber an Ecto gebunden statt
  an Ash.
- **Nur Magic Link oder Passwort**: einfacher, entspricht aber nicht dem Wunsch nach
  Passkeys.

## Konsequenzen

- Mehr Eigenbau als bei den anderen Login-Arten, daher eine eigene Ausbaustufe nach den
  Kernfunktionen.
- WebAuthn verlangt einen sicheren Kontext: `localhost` funktioniert in der
  Entwicklung, im Betrieb ist HTTPS nötig.
