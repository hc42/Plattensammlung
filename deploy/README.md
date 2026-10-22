# Betrieb auf TrueNAS

Anleitung für den Betrieb auf einem NAS mit **TrueNAS 25.10** hinter
**nginx-proxy-manager** (NPM). Hintergrund und Entscheidungen: [ADR 0011](../docs/adr/0011-betrieb-auf-truenas.md).

```
Internet ──443──▶ nginx-proxy-manager ──http──▶ NAS:4000 (app) ──▶ db (Postgres 18)
```

`POOL` steht im Folgenden für den Namen deines Pools, `platten.example.de` für deine Domain.

## 1. Datasets anlegen (einmalig)

In TrueNAS unter **Datasets** (Preset „Apps“):

```
POOL/apps/plattensammlung
├── postgres   Datenbank
├── covers     Cover-Bilder
├── backups    Datenbank-Dumps
└── images     Image-Dateien zum Laden
```

Die App läuft im Container als Benutzer `nobody` (UID 65534) und muss in `covers` schreiben.
In der TrueNAS-Shell (**System → Shell**):

```bash
sudo chown 65534:65534 /mnt/POOL/apps/plattensammlung/covers
```

## 2. Konfiguration (einmalig)

Zwei Secrets auf dem Mac erzeugen (im Projektordner, zweimal ausführen):

```bash
mix phx.gen.secret
```

Auf dem NAS die Dateien `app.env` und `db.env` nach den Vorlagen
[`app.env.example`](app.env.example) und [`db.env.example`](db.env.example) anlegen,
ausfüllen und schützen:

```bash
sudo chmod 600 /mnt/POOL/apps/plattensammlung/app.env /mnt/POOL/apps/plattensammlung/db.env
```

- `PHX_HOST` ist genau die Domain aus nginx-proxy-manager. Davon hängen Passkeys und
  Anmeldelinks ab.
- Das Datenbank-Passwort steht zweimal: in `db.env` (`POSTGRES_PASSWORD`) und in der
  `DATABASE_URL` in `app.env`.
- SMTP: Zugangsdaten deines Mailanbieters. Port 587 nutzt STARTTLS, Port 465 TLS.
  `MAIL_FROM` ist meist deine eigene Adresse.

Das Backup-Skript aufs NAS kopieren:

```bash
scp deploy/backup.sh <nas>:/mnt/POOL/apps/plattensammlung/
```

## 3. Image bauen und aufs NAS laden

Auf dem Mac (Podman muss laufen). Der Build für amd64 läuft per Emulation und dauert
einige Minuten:

```bash
deploy/build-image.sh
```

Das Skript zeigt am Ende den Dateinamen und die Befehle zum Kopieren und Laden, etwa:

```bash
scp dist/plattensammlung-20261021-abc1234.tar.gz <nas>:/mnt/POOL/apps/plattensammlung/images/
```

```bash
ssh <nas> sudo docker load -i /mnt/POOL/apps/plattensammlung/images/plattensammlung-20261021-abc1234.tar.gz
```

## 4. App in TrueNAS installieren (einmalig)

**Apps → Discover Apps → ⋮ → Install via YAML**, Name `plattensammlung`, Inhalt von
[`truenas-compose.yaml`](truenas-compose.yaml) einfügen und darin ersetzen:

- `/mnt/POOL/apps/plattensammlung` durch deinen Pfad
- `VERSION` durch die Version aus Schritt 3 (`localhost/plattensammlung:20261021-abc1234`)
- bei Bedarf den Port `4000:4000` (links der Port auf dem NAS)

Beim Start legt die App die Datenbanktabellen automatisch an. In den App-Logs sollte
`Running PlattensammlungWeb.Endpoint` erscheinen. Prüfen im LAN:

```bash
curl http://<NAS-IP>:4000/health
```

## 5. nginx-proxy-manager

Neuer **Proxy Host**:

| Feld | Wert |
|---|---|
| Domain Names | `platten.example.de` |
| Scheme / Forward Hostname / Port | `http` / NAS-IP / `4000` |
| **Websockets Support** | **an** (sonst funktioniert die Oberfläche nicht) |
| Block Common Exploits | an |
| SSL | neues Let's-Encrypt-Zertifikat, **Force SSL**, HTTP/2 |

Die Portfreigabe im Router (443, für Let's Encrypt meist auch 80) zeigt auf
nginx-proxy-manager, **nicht** auf Port 4000 der App.

NPM setzt den Header `X-Forwarded-For`; daraus liest die App die IP-Adresse der Besucher
(für Rate Limits und Logs, ADR 0017). Wer Port 4000 direkt erreicht (im LAN), könnte
den Header selbst setzen. Deshalb Port 4000 nicht ins Internet freigeben.

### Unter einem Pfad statt einer eigenen Domain (optional)

Soll die App unter `https://cloud.example.com/plattensammlung` laufen, neben anderen Apps
auf derselben Domain (ADR 0018):

1. In `app.env`: `PHX_HOST=cloud.example.com` und `PHX_PATH=/plattensammlung`, dann die
   App neu starten.
2. Im Proxy Host von `cloud.example.com` unter **Advanced → Custom Nginx Configuration**:

   ```nginx
   location /plattensammlung/ {
     # The trailing slash strips the prefix: the app itself serves under /
     proxy_pass http://NAS-IP:4000/;
     proxy_http_version 1.1;
     proxy_set_header Upgrade $http_upgrade;
     proxy_set_header Connection "upgrade";
     proxy_set_header Host $host;
     proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
     proxy_set_header X-Forwarded-Proto $scheme;
   }

   location = /plattensammlung {
     return 301 /plattensammlung/;
   }
   ```

   Wichtig sind der Schrägstrich am Ende von `proxy_pass` (er schneidet das Präfix ab) und
   die beiden Upgrade-Zeilen (Websockets für die Oberfläche).
3. Passkeys hängen nur an der Domain, nicht am Pfad. Ein Passkey für `cloud.example.com`
   gilt also auch für andere Apps auf dieser Domain, die Passkeys anbieten. Das ist
   harmlos, sie sehen ihn nur in der Auswahl.

Ohne `PHX_PATH` läuft die App wie bisher unter `/`.

### Grobschutz gegen Massenanfragen (optional, empfohlen)

Die App begrenzt Anmeldelinks selbst. Zusätzlich kann NPM jede IP-Adresse drosseln:

1. Auf dem NAS die Datei `/data/nginx/custom/http_top.conf` im Datenordner von NPM
   anlegen (bei der TrueNAS-App von NPM im Volume für `/data`):

   ```nginx
   limit_req_zone $binary_remote_addr zone=plattensammlung:10m rate=10r/s;
   ```

2. Im Proxy Host unter **Advanced → Custom Nginx Configuration**:

   ```nginx
   limit_req zone=plattensammlung burst=50 nodelay;
   limit_req_status 429;
   ```

3. NPM neu starten. Der erste Seitenaufruf lädt einige Dateien auf einmal; `burst=50`
   lässt das zu, dauerhaft mehr als 10 Anfragen pro Sekunde werden mit 429 abgewiesen.

## 6. Erste Anmeldung

1. `https://platten.example.de` öffnen, deine Adresse aus `ALLOWED_EMAILS` eingeben.
2. Den Link aus der E-Mail öffnen und „Jetzt anmelden“ klicken.
3. Unter **Konto** einen Passkey anlegen. Passkeys von `localhost` aus der Entwicklung
   gelten hier nicht.

## 7. Backups

- **Datenbank:** **System → Advanced Settings → Cron Jobs → Add**, Benutzer `root`, z. B.
  täglich 3:00:

  ```bash
  /mnt/POOL/apps/plattensammlung/backup.sh /mnt/POOL/apps/plattensammlung/backups 30
  ```

- **Cover und Dumps:** **Data Protection → Periodic Snapshot Tasks** für
  `POOL/apps/plattensammlung` (rekursiv), optional mit Replikation auf ein anderes Gerät.
- Zusätzlich als lesbare Sicherung: CSV-Export auf der Statistikseite.
- Verwaiste Cover-Dateien räumt die App bei jedem Start auf. Von Hand:

  ```bash
  sudo docker exec $(sudo docker ps -q --filter label=com.docker.compose.project=ix-plattensammlung --filter label=com.docker.compose.service=app) /app/bin/plattensammlung rpc "Plattensammlung.Covers.cleanup_orphans()"
  ```

Wiederherstellen eines Dumps (App vorher stoppen, dann nur `db` starten oder die App kurz
laufen lassen):

```bash
gunzip -c /mnt/POOL/apps/plattensammlung/backups/plattensammlung-DATUM.sql.gz | sudo docker exec -i $(sudo docker ps -q --filter label=com.docker.compose.project=ix-plattensammlung --filter label=com.docker.compose.service=db) psql -U postgres plattensammlung
```

## 8. Updates

1. Auf dem Mac `deploy/build-image.sh` ausführen und das neue Image wie in Schritt 3 laden.
2. In TrueNAS die App bearbeiten, die Zeile `image:` auf die neue Version setzen und speichern.
   Migrationen laufen beim Start automatisch.
3. Alte Images auf dem NAS gelegentlich aufräumen: `sudo docker image prune`.

## Fehlersuche

| Symptom | Ursache |
|---|---|
| Seite lädt, reagiert aber nicht / „Verbindung wird wiederhergestellt“ | Websockets Support in NPM fehlt |
| Passkey-Fehler | `PHX_HOST` stimmt nicht exakt mit der Domain überein |
| Keine Anmelde-E-Mail | App-Logs prüfen (SMTP-Fehler), Adresse in `ALLOWED_EMAILS`? |
| App startet nicht | App-Logs: meist eine fehlende Variable in `app.env` |
| Cover werden nicht gespeichert | Rechte von `covers` (Schritt 1) |
