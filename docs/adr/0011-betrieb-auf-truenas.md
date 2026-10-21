# 0011. Betrieb auf TrueNAS hinter nginx-proxy-manager

- **Status:** Angenommen (umgesetzt am 2026-10-21)
- **Datum:** 2026-10-21

## Kontext

Die App soll dauerhaft laufen und **öffentlich über eine eigene Domain** erreichbar sein,
geschützt durch Login und Freigabeliste ([ADR 0005](0005-passkey-login.md)).
Vorhanden sind:

- ein NAS mit **TrueNAS 25.10**; Apps laufen dort als Docker-Container, eigene Apps als
  „Custom App“ per Compose-YAML
- **nginx-proxy-manager** (NPM) als vorgelagerter HTTP-Proxy, der Domain,
  Portfreigabe und Let's-Encrypt-Zertifikat übernimmt
- ein Mailanbieter mit **SMTP**-Zugang

Passkeys verlangen ein gültiges Zertifikat und einen festen Hostnamen. Das ist mit
Domain und NPM gegeben, nicht aber mit dem selbstsignierten LAN-Zertifikat aus
[ADR 0008](0008-https-im-lan.md).

## Entscheidung

```
Internet ──443──▶ nginx-proxy-manager ──http──▶ app:4000 ──▶ db:5432
                  (TLS, Let's Encrypt)          (Phoenix)     (Postgres 18)
```

**Image**

- Elixir-Release (`mix release`) in einem Container, Dockerfile nach
  `mix phx.gen.release --docker`. Die Build-Stage bekommt Node.js für `npm install`
  (ZXing). Gebaut wird für **linux/amd64**.
- Beim Start laufen automatisch die Migrationen (`bin/migrate`), danach `bin/server`.
- Ein einfacher Health-Endpunkt `GET /health` für den Container-Healthcheck.

**TrueNAS Custom App (Compose)**

- Container `app` (Image aus der Registry) und `db` (`postgres:18`).
- ZFS-Datasets als Host-Pfade: `…/plattensammlung/postgres` (Datenbank) und
  `…/plattensammlung/covers` (Cover-Bilder).
- Nur der App-Port ist im LAN erreichbar, damit NPM ihn ansprechen kann. Postgres bleibt
  im internen Netz der App.

**Konfiguration** (Umgebungsvariablen der App)

| Variable | Inhalt |
|---|---|
| `PHX_HOST` | öffentliche Domain, z. B. `platten.example.de` |
| `SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET` | zufällig, mit `mix phx.gen.secret` erzeugt |
| `DATABASE_URL` | `ecto://postgres:<pw>@db/plattensammlung` |
| `ALLOWED_EMAILS` | wer sich anmelden darf |
| `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD`, `MAIL_FROM` | Mailversand über den eigenen Anbieter (Swoosh SMTP-Adapter) |
| `COVERS_DIR` | Pfad des Cover-Volumes im Container |
| `DISCOGS_TOKEN`, `MUSICBRAINZ_CONTACT` | optional |

**Anpassungen im Code**

- Die öffentliche Adresse kommt im Betrieb aus `PHX_HOST` (https, Port 443) statt aus der
  Anfrage. Das betrifft WebAuthn-Origin und RP-ID, Magic-Link-URL, absolute Cover-URLs im
  JSON-LD und die Server-URL in OpenAPI. In der Entwicklung bleibt es bei der
  Anfrage-Adresse (localhost, `.local`).
- `check_origin` für LiveView-Websockets auf die Domain beschränken.
- Session-Cookie mit `secure`.
- Mailversand: `gen_smtp` als Abhängigkeit, SMTP-Konfiguration in `runtime.exs` für prod.

**nginx-proxy-manager**

- Proxy Host für die Domain → `http://<NAS-IP>:<App-Port>`, **Websockets Support an**,
  SSL mit Let's Encrypt, „Force SSL“ und HTTP/2.

**Backups**

- Täglicher `pg_dump` (TrueNAS Cron Job: `docker exec … pg_dump`) in ein eigenes Dataset.
- ZFS-Snapshots der Datasets (Datenbank-Dump und Cover), optional Replikation.
- Zusätzlich jederzeit der CSV-Export aus der App ([ADR 0010](0010-statistik-und-export.md)).

**Auslieferung des Images:** lokal auf dem Mac mit Podman für amd64 bauen (Emulation),
als Datei speichern (`deploy/build-image.sh`), per `scp` aufs NAS kopieren und dort mit
`docker load` laden. Es braucht keine Registry und kein externes Konto. Die Compose-Datei
verweist auf `localhost/plattensammlung:<version>` mit `pull_policy: never`.

**Umsetzung im Repository:** `deploy/` enthält Compose-Datei, Env-Vorlagen, Build- und
Backup-Skript sowie die Anleitung ([deploy/README.md](../../deploy/README.md)). Secrets
liegen in `app.env` und `db.env` auf dem NAS, nicht im Git und nicht in der
TrueNAS-Oberfläche. Der Datenbank-Container bekommt nur sein eigenes Passwort.

## Betrachtete Alternativen

- **GitHub Actions und GitHub Container Registry**: bequeme Updates per `git push`, aber
  ein externes Konto und Registry-Zugangsdaten auf dem NAS nötig.
- **VPS mit Caddy**: unabhängig vom Heimnetz, kostet aber monatlich und braucht eigene
  Pflege. Das NAS ist vorhanden.
- **Nur per VPN (Tailscale)** erreichbar: sicherer, aber kein Zugang ohne VPN-Client.
- **TLS direkt in Phoenix**: doppelte Zertifikatsverwaltung, da NPM ohnehin
  Zertifikate verwaltet.

## Konsequenzen

- Die App ist öffentlich erreichbar. Schutz bieten Login, Freigabeliste und Ash-Policies.
  `/dev` (Postfach, Dashboard) gibt es in prod nicht.
- Passkeys funktionieren unter der Domain. Passkeys von `localhost` gelten dort nicht,
  man legt sie unter der Domain neu an.
- Updates: neues Image bauen und in TrueNAS die App aktualisieren. Migrationen laufen
  beim Start mit.
