# Running on TrueNAS

Guide for running the app on a NAS with **TrueNAS 25.10** behind **nginx-proxy-manager** (NPM).
Background and decisions: [ADR 0011](../docs/adr/0011-running-on-truenas.md).

```
Internet ──443──▶ nginx-proxy-manager ──http──▶ NAS:4000 (app) ──▶ db (Postgres 18)
```

Below, `POOL` stands for the name of your pool and `platten.example.de` for your domain.

## 1. Create datasets (once)

In TrueNAS under **Datasets** (preset "Apps"):

```
POOL/apps/plattensammlung
├── postgres   database
├── covers     cover images
├── backups    database dumps
└── images     image files to load
```

The app runs in the container as user `nobody` (UID 65534) and must write to `covers`. In the
TrueNAS shell (**System → Shell**):

```bash
sudo chown 65534:65534 /mnt/POOL/apps/plattensammlung/covers
```

## 2. Configuration (once)

Create two secrets on the Mac (in the project folder, run it twice):

```bash
mix phx.gen.secret
```

On the NAS create the files `app.env` and `db.env` from the templates
[`app.env.example`](app.env.example) and [`db.env.example`](db.env.example), fill them in and
protect them:

```bash
sudo chmod 600 /mnt/POOL/apps/plattensammlung/app.env /mnt/POOL/apps/plattensammlung/db.env
```

- `PHX_HOST` is exactly the domain from nginx-proxy-manager. Passkeys and sign-in links depend
  on it.
- The database password appears twice: in `db.env` (`POSTGRES_PASSWORD`) and in the
  `DATABASE_URL` in `app.env`.
- SMTP: credentials of your mail provider. Port 587 uses STARTTLS, port 465 TLS. `MAIL_FROM` is
  usually your own address.

Copy the backup script to the NAS:

```bash
scp deploy/backup.sh <nas>:/mnt/POOL/apps/plattensammlung/
```

## 3. Build the image and load it on the NAS

On the Mac (Podman must be running). The build for amd64 runs under emulation and takes a few
minutes:

```bash
deploy/build-image.sh
```

At the end the script shows the file name and the commands to copy and load it, e.g.:

```bash
scp dist/plattensammlung-20261021-abc1234.tar.gz <nas>:/mnt/POOL/apps/plattensammlung/images/
```

```bash
ssh <nas> sudo docker load -i /mnt/POOL/apps/plattensammlung/images/plattensammlung-20261021-abc1234.tar.gz
```

## 4. Install the app in TrueNAS (once)

**Apps → Discover Apps → ⋮ → Install via YAML**, name `plattensammlung`, paste the content of
[`truenas-compose.yaml`](truenas-compose.yaml) and replace in it:

- `/mnt/POOL/apps/plattensammlung` with your path
- `VERSION` with the version from step 3 (`localhost/plattensammlung:20261021-abc1234`)
- if needed the port `4000:4000` (left: the port on the NAS)

On start the app creates the database tables automatically. The app logs should show
`Running PlattensammlungWeb.Endpoint`. Check in the LAN:

```bash
curl http://<NAS-IP>:4000/health
```

## 5. nginx-proxy-manager

New **proxy host**:

| Field | Value |
|---|---|
| Domain Names | `platten.example.de` |
| Scheme / Forward Hostname / Port | `http` / NAS IP / `4000` |
| **Websockets Support** | **on** (otherwise the interface doesn't work) |
| Block Common Exploits | on |
| SSL | new Let's Encrypt certificate, **Force SSL**, HTTP/2 |

The port forwarding in the router (443, for Let's Encrypt usually also 80) points to
nginx-proxy-manager, **not** to port 4000 of the app.

NPM sets the header `X-Forwarded-For`; the app reads the visitors' IP address from it (for rate
limits and logs, ADR 0017). Whoever reaches port 4000 directly (in the LAN) could set the header
themselves. So don't expose port 4000 to the internet.

### Under a path instead of an own domain (optional)

To run the app at `https://cloud.example.com/plattensammlung`, next to other apps on the same
domain (ADR 0018):

1. In `app.env`: `PHX_HOST=cloud.example.com` and `PHX_PATH=/plattensammlung`, then restart the
   app.
2. In the proxy host of `cloud.example.com` under **Advanced → Custom Nginx Configuration**:

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

   What matters is the trailing slash of `proxy_pass` (it strips the prefix) and the two upgrade
   lines (websockets for the interface).
3. Passkeys are bound to the domain only, not the path. A passkey for `cloud.example.com` also
   applies to other apps on this domain that offer passkeys. That's harmless, they only see it
   in the selection.

Without `PHX_PATH` the app runs under `/` as before.

### Coarse protection against mass requests (optional, recommended)

The app limits sign-in links itself. In addition NPM can throttle each IP address:

1. On the NAS create the file `/data/nginx/custom/http_top.conf` in NPM's data folder (for the
   TrueNAS NPM app in the volume for `/data`):

   ```nginx
   limit_req_zone $binary_remote_addr zone=plattensammlung:10m rate=10r/s;
   ```

2. In the proxy host under **Advanced → Custom Nginx Configuration**:

   ```nginx
   limit_req zone=plattensammlung burst=50 nodelay;
   limit_req_status 429;
   ```

3. Restart NPM. The first page load fetches several files at once; `burst=50` allows that,
   sustained rates above 10 requests per second are rejected with 429.

## Metrics and traces (optional)

The app serves metrics for Prometheus on port **9568** (`METRICS_PORT`, already set in
`truenas-compose.yaml`) and, on request, traces via OpenTelemetry to Tempo (ADR 0019). Grafana
shows both; dashboards and alerts are included.

1. Create the dataset `POOL/apps/observability` and copy into it:
   `deploy/observability/prometheus.yml`, `tempo.yaml` and the folder `grafana/` (with
   `provisioning/` and `dashboards/`). Replace `NAS-IP` in `prometheus.yml`.
2. Create empty folders `prometheus-data`, `tempo-data`, `grafana-data`. The containers don't
   run as root: set the owners (Prometheus `65534`, Tempo `10001`, Grafana `472`), e.g.
   `chown -R 472:472 grafana-data`.
3. Copy `deploy/observability/grafana.env.example` to `/mnt/POOL/apps/observability/grafana.env`
   and fill it in (admin password, `ALERT_EMAIL`, SMTP access as in `app.env`).
4. **Apps → Discover Apps → ⋮ → Install via YAML** with `deploy/observability/compose.yaml`
   (adjust the paths).
5. For traces add `OTEL_EXPORTER_OTLP_ENDPOINT=http://NAS-IP:4318` to `app.env` and restart the
   app.
6. Open Grafana at `http://NAS-IP:3000` (user `admin`): dashboards **Plattensammlung** and
   **Plattensammlung – Traces** (service graph, figures from the traces, lists of slow or failed
   traces), traces under **Explore → Tempo**.
7. **Alerts by e-mail:** the rules are in `grafana/provisioning/alerting/rules.yaml` (app
   unreachable, many requests, many anonymous requests, failed sign-ins, rate-limited magic
   links, server errors, slow responses, external services failing). Adjust thresholds there,
   not in Grafana. Test: in Grafana under **Alerting → Contact points → E-Mail → Test**.

Tempo computes the figures from the traces itself and writes them into Prometheus
(`--web.enable-remote-write-receiver`, already in `compose.yaml`).

**Storage:** traces stay 14 days (about 100 MB), metrics 90 days, at most 2 GB. Check the usage:
`du -sh /mnt/POOL/apps/observability/*`.

**Updates:** Dependabot also updates the Prometheus, Tempo and Grafana images. Major versions can
change the configuration (Tempo 3 did); check them locally with
`podman compose --profile observability up -d` before updating the NAS.

Use ports 9568 (metrics), 4318 (traces), 9090 (Prometheus) and 3000 (Grafana) only in the LAN;
don't expose them in nginx-proxy-manager or the router. Check: `curl http://NAS-IP:9568/metrics`.

## 6. First sign-in

1. Open `https://platten.example.de` and enter your address from `ALLOWED_EMAILS`.
2. Open the link from the e-mail and click "Jetzt anmelden" (sign in now).
3. Create a passkey under **Konto** (account). Passkeys from `localhost` in development don't
   apply here.

## 7. Backups

- **Database:** **System → Advanced Settings → Cron Jobs → Add**, user `root`, e.g. daily at
  3:00:

  ```bash
  /mnt/POOL/apps/plattensammlung/backup.sh /mnt/POOL/apps/plattensammlung/backups 30
  ```

- **Covers and dumps:** **Data Protection → Periodic Snapshot Tasks** for
  `POOL/apps/plattensammlung` (recursive), optionally with replication to another device.
- In addition, as a readable backup: the CSV export on the statistics page.
- The app cleans up orphaned cover files on every start. By hand:

  ```bash
  sudo docker exec $(sudo docker ps -q --filter label=com.docker.compose.project=ix-plattensammlung --filter label=com.docker.compose.service=app) /app/bin/plattensammlung rpc "Plattensammlung.Covers.cleanup_orphans()"
  ```

Restoring a dump (stop the app first, then start only `db`, or let the app run briefly):

```bash
gunzip -c /mnt/POOL/apps/plattensammlung/backups/plattensammlung-DATE.sql.gz | sudo docker exec -i $(sudo docker ps -q --filter label=com.docker.compose.project=ix-plattensammlung --filter label=com.docker.compose.service=db) psql -U postgres plattensammlung
```

## 8. Updates

1. Run `deploy/build-image.sh` on the Mac and load the new image as in step 3.
2. In TrueNAS edit the app, set the `image:` line to the new version and save. Migrations run
   automatically on start.
3. Clean up old images on the NAS now and then: `sudo docker image prune`.

## Troubleshooting

| Symptom | Cause |
|---|---|
| Page loads but doesn't react / "Verbindung wird wiederhergestellt" (reconnecting) | websockets support missing in NPM |
| Passkey errors | `PHX_HOST` doesn't exactly match the domain |
| No sign-in e-mail | check the app logs (SMTP error); is the address in `ALLOWED_EMAILS`? |
| App doesn't start | app logs: usually a missing variable in `app.env` |
| Covers aren't stored | permissions of `covers` (step 1) |
| Tempo doesn't start after an update | `tempo.yaml` doesn't match the new major version (see ADR 0019) |
