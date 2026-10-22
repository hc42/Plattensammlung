# Sicherheit

Plattensammlung ist eine private Anwendung für einen kleinen, bekannten Personenkreis. Dieses
Dokument beschreibt, wie Sicherheitsprobleme gemeldet werden, welches Sicherheitsmodell gilt
und welche Grenzen bekannt sind. Die Begründungen stehen in den ADRs unter [docs/adr/](docs/adr/).

## Sicherheitslücken melden

- Bitte **nicht** öffentlich melden (kein Issue, kein Chat), sondern vertraulich direkt an den
  Betreiber der Instanz.
- Hilfreich sind: betroffene Seite oder API-Route, Schritte zum Nachstellen, erwartetes und
  tatsächliches Verhalten, Einschätzung der Auswirkung.
- Keine Tests gegen fremde Instanzen und keine Daten anderer Benutzer abrufen oder verändern,
  um eine Lücke zu belegen.

## Unterstützte Versionen

Es gibt keine Versionszweige. Sicherheitskorrekturen kommen in `main` und werden mit einem
neuen Image ausgerollt (siehe [deploy/README.md](deploy/README.md)).

## Sicherheitsmodell

### Anmeldung ([ADR 0005](docs/adr/0005-passkey-login.md))

- Anmelden können nur Adressen aus `ALLOWED_EMAILS`. Es gibt keine offene Registrierung.
- **Passkeys** (WebAuthn) als Hauptweg, **Anmeldelink** per E-Mail als Rückfallebene. Es gibt
  keine Passwörter.
- Die Anmeldeseite verrät nicht, ob eine Adresse freigeschaltet ist.
- **API-Keys** werden nur als Hash gespeichert, einmalig angezeigt und laufen nach 30 Tagen oder
  einem Jahr ab.
- Sitzungen liegen in einem signierten Cookie (`SameSite=Lax`, in Produktion `Secure`).
  AshAuthentication prüft zusätzlich, dass das Sitzungstoken in der Datenbank existiert.

### Berechtigungen ([ADR 0013](docs/adr/0013-eigene-sammlungen.md), [0015](docs/adr/0015-gemeinsame-kuenstler.md), [0016](docs/adr/0016-gemeinsame-alben.md))

- Alle Zugriffe laufen über Ash-Actions mit Policies; ohne Anmeldung ist nichts lesbar.
- Alben und Künstler sind gemeinsam. Albumdaten ändert, wer das Album in Sammlung oder
  Wunschliste hat. Gelöscht wird ein Album erst, wenn es niemand mehr hat. Einen Künstler
  umbenennen oder löschen darf man nur, solange niemand sonst ein Album von ihm hat.
- Exemplare und Wünsche gehören einer Person; nur sie ändert oder löscht sie.
- **Kaufdatum und Notizen** eines Exemplars sind per Field Policy nur für den Besitzer lesbar,
  auch über die API.
- Andere Benutzer sehen nur ID und Anzeigenamen, nie die E-Mail-Adresse.

### Eingaben und Ausgaben ([ADR 0006](docs/adr/0006-datenmodell.md), [ADR 0014](docs/adr/0014-cover-quellen-und-csp.md))

- HEEx escapt alle Ausgaben; es gibt kein `raw` und kein `innerHTML` in JavaScript.
- Alle Felder haben Typ-, Längen- und Wertgrenzen; Barcodes werden normalisiert und geprüft.
- **Cover** werden nur per HTTPS von bekannten Quellen geladen (Discogs, Cover Art Archive),
  auch bei Weiterleitungen (Schutz vor SSRF). Lokale Cover-Pfade setzt nur die App selbst.
  Hochgeladene Bilder werden am Inhalt erkannt (Magic Bytes), höchstens 10 MB.
- **Content-Security-Policy:** Skripte nur von der App (Nonce für das Inline-Skript),
  Bilder nur von der App und den Cover-Quellen, keine Frames, Formulare nur an die App.
- CSRF-Schutz für alle Formulare und LiveView; die API akzeptiert nur Bearer-Keys, keine
  Sitzungs-Cookies.

### Missbrauch begrenzen ([ADR 0017](docs/adr/0017-rate-limits.md))

- Anmeldelinks: höchstens 3 pro Adresse in 15 Minuten und 10 pro IP-Adresse pro Stunde.
- Abfragen bei MusicBrainz werden auf 1 pro Sekunde gedrosselt.
- Optionales `limit_req` in nginx-proxy-manager als Grobschutz.

### Betrieb ([ADR 0011](docs/adr/0011-betrieb-auf-truenas.md), [ADR 0019](docs/adr/0019-metriken-und-traces.md))

- TLS endet bei nginx-proxy-manager; die App erzwingt HTTPS (HSTS) über `X-Forwarded-Proto`.
- Geheimnisse (`SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET`, Datenbank- und SMTP-Passwörter)
  stehen nur in `app.env`/`db.env`/`grafana.env` auf dem NAS (`chmod 600`), nie im Git oder im
  Image. Das Image enthält keine Uploads und keine Zertifikate.
- Nur Port 4000 (über den Proxy) ist aus dem Internet erreichbar. Metriken (9568), Traces
  (4318), Prometheus (9090) und Grafana (3000) sind nur fürs LAN gedacht.
- `/dev` (Postfach mit Anmeldelinks, LiveDashboard) gibt es nur in der Entwicklung und nur von
  `localhost` aus.
- Traces schicken keine Trace-Header an Discogs, MusicBrainz oder Wikidata.
- Die App schickt keine personenbezogenen Daten an externe Dienste; der MusicBrainz-Kontakt im
  User-Agent ist optional (`MUSICBRAINZ_CONTACT`).

## Bekannte Grenzen

- **`X-Forwarded-For`** wird ohne Liste vertrauenswürdiger Proxys gelesen. Wer Port 4000 direkt
  erreicht (im LAN), kann die eigene IP-Adresse fälschen und das Limit pro IP umgehen; das
  Limit pro Adresse gilt trotzdem. Port 4000 darf deshalb nicht ins Internet.
- **Rate Limits** liegen im Arbeitsspeicher und beginnen nach einem Neustart neu.
- **Angemeldeten Benutzern wird vertraut:** Für sie gibt es keine Rate Limits, und wer ein
  Album hat, kann dessen gemeinsame Daten (Cover, Links) für alle ändern.
- **Passkeys** gelten für die ganze Domain. Läuft die App unter einem Pfad einer gemeinsamen
  Domain ([ADR 0018](docs/adr/0018-pfad-praefix.md)), sehen andere Apps dort den Passkey in der
  Auswahl.
- Der **Metrik-Port** und **Grafana** haben keine eigene Anmeldung bzw. nur das Admin-Passwort;
  sie verlassen sich auf das LAN. Metriken enthalten Benutzer-IDs, aber keine E-Mail-Adressen.
- Die API liefert `cover_url` als Pfad relativ zur App.

## Für Entwickler

- Neue Actions brauchen Policies; Daten nur über Ash lesen und schreiben (siehe
  [AGENTS.md](AGENTS.md)).
- Neue Felder bekommen Längen- bzw. Wertgrenzen, private Felder eine Field Policy.
- Pfade nie als feste Zeichenkette, URLs zu Bildern nur von erlaubten Quellen.
- Vor einem Release: `mix precommit` und `mix hex.audit` (zurückgezogene oder als unsicher
  gemeldete Pakete).
