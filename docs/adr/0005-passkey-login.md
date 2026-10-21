# 0005. Login per Passkey

- **Status:** Angenommen (umgesetzt am 2026-10-21)
- **Datum:** 2026-10-21

## Kontext

Die Anmeldung soll per **Passkey** (WebAuthn/FIDO2) erfolgen. AshAuthentication
(Version 4.15) bringt Strategien für Passwort, Magic Link, API-Keys, OAuth2 und weitere
mit, aber **keine Passkey-Strategie**. Die JSON-API ([ADR 0009](0009-gestaltung-der-json-api.md))
braucht ebenfalls eine Authentifizierung. Die App verwaltet eine private Sammlung; nur
wenige, bekannte Personen sollen Zugang haben.

## Entscheidung

- **AshAuthentication** (Domain `Plattensammlung.Accounts`) verwaltet `User`, Sessions
  und Tokens. Strategien: **Magic Link** und **API-Key**. Es gibt keine Passwörter.
- **Passkeys** werden selbst gebaut, mit der Bibliothek **`wax_`**:
  - Resource `Passkey` (Credential-ID, Public Key als COSE-Key, Sign-Count, Name,
    zuletzt benutzt), gehört zu einem `User`.
  - `Accounts.WebAuthn` kapselt das Protokoll (Challenge erzeugen, Antwort prüfen).
  - `PasskeyController` stellt vier JSON-Endpunkte unter `/auth/passkey/` bereit. Die
    Challenge liegt zwischen den beiden Anfragen in der Session und gilt nur einmal.
  - JS-Hooks `PasskeySignIn` und `PasskeyRegister` rufen `navigator.credentials.get/create`
    auf.
  - *Discoverable credentials*: Beim Anmelden muss man keine E-Mail-Adresse eingeben,
    das Gerät bietet die passenden Passkeys an.
  - Origin und RP-ID werden aus der aktuellen Anfrage abgeleitet, damit `localhost` und
    `<name>.local` funktionieren.
- **Magic Link** (E-Mail) als Rückfallebene und für die erste Anmeldung. Der Link zeigt
  auf die Adresse, von der aus er angefordert wurde. Lokal landen die E-Mails im
  Swoosh-Postfach `/dev/mailbox` (nur von `localhost` aus erreichbar).
- **Freigabeliste:** Nur Adressen aus `ALLOWED_EMAILS` erhalten einen Link und dürfen sich
  anmelden (Validation am Magic-Link-Sign-in, Prüfung beim Passkey-Login). Die
  Anmeldeseite verrät nicht, ob eine Adresse freigeschaltet ist.
- **API:** `Authorization: Bearer <API-Key>`. Keys werden auf der Kontoseite erzeugt
  (30 Tage oder 1 Jahr gültig), nur als Hash gespeichert und einmalig angezeigt.
- **Autorisierung mit Ash-Policies:** Alle Records-Resources verlangen einen Actor
  (`actor_present()`, `access_type :strict`). Es gibt *eine* gemeinsame Sammlung für
  alle angemeldeten Benutzer. Passkeys und API-Keys sieht nur ihr Besitzer.

## Betrachtete Alternativen

- **`webauthn_components`**: fertige LiveView-Komponenten, aber an Ecto gebunden statt
  an Ash.
- **Passkey-Login über eine LiveView** statt über einen Controller: Eine LiveView kann
  keine Session-Cookies setzen. Dafür bräuchte es einen Umweg über einen kurzlebigen
  Token und eine Weiterleitung. Der Controller ist direkter.
- **Nur Magic Link oder Passwort**: einfacher, entspricht aber nicht dem Wunsch nach
  Passkeys.
- **Offene Registrierung**: Ohne Freigabeliste könnte sich jeder im Netz ein Konto anlegen.

## Konsequenzen

- WebAuthn verlangt einen sicheren Kontext: `localhost` funktioniert immer. Mit dem
  selbstsignierten Zertifikat aus [ADR 0008](0008-https-im-lan.md) verweigern manche
  Browser Passkeys, Chrome z. B. bei Zertifikatsfehlern. Auf dem Handy bleibt dann der
  Magic Link.
- Ein Passkey gilt nur für den Hostnamen, unter dem er angelegt wurde (`localhost` oder
  `<name>.local`).
- `ALLOWED_EMAILS` muss gesetzt sein, sonst kann sich niemand anmelden.
- Alle Aufrufe der Domain `Records` brauchen `actor:` (oder in Seeds bewusst
  `authorize?: false`).
- Für den Betrieb fehlen noch ein echter Mailversand (z. B. SMTP) und ein echtes
  Zertifikat.
