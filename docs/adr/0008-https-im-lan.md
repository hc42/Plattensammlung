# 0008. HTTPS im lokalen Netz für den Kamera-Scan

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

Der Barcode-Scan mit der Handykamera ([ADR 0007](0007-barcode-scan-und-import.md))
braucht `getUserMedia`, und Browser erlauben das nur in einem sicheren Kontext: HTTPS
oder `localhost`. Das Handy greift aber über das WLAN auf den Entwicklungsrechner zu.
Die App hat noch keinen Login ([ADR 0005](0005-passkey-login.md)).

## Entscheidung

- Ein **selbstsigniertes Zertifikat** wird mit `mix phx.gen.cert` für `localhost` und den
  mDNS-Namen des Macs (`<LocalHostName>.local`) erzeugt. Es liegt in `priv/cert/` und ist
  nicht im Git.
- HTTPS ist **opt-in**: Nur mit `LAN=1 mix phx.server` lauscht der Server zusätzlich auf
  `0.0.0.0:4001` (HTTPS). HTTP auf Port 4000 bleibt auf `127.0.0.1` beschränkt.
- Zusätzlich gibt es **„Foto aufnehmen“** (`<input type="file" capture>`). Das braucht
  keinen sicheren Kontext und funktioniert daher auch ohne HTTPS.

## Betrachtete Alternativen

- **mkcert** (lokale Zertifizierungsstelle): Damit gäbe es keine Zertifikatswarnung, aber
  die Root-CA müsste auf jedem Handy installiert und als vertrauenswürdig markiert
  werden. Das ist für den Anfang zu umständlich, und mkcert ist nicht installiert.
- **Tunnel-Dienst** (z. B. ngrok, Cloudflare Tunnel): Damit gäbe es ein gültiges
  Zertifikat, aber die App ohne Login wäre im Internet erreichbar. Verworfen.
- **HTTPS immer an**: Die App wäre ungefragt im WLAN offen. Verworfen, solange es keinen
  Login gibt.

## Konsequenzen

- Beim ersten Aufruf zeigt das Handy eine Zertifikatswarnung, die man einmal bestätigen
  muss.
- Mit `LAN=1` sind im WLAN auch die Fehlerseiten der Entwicklung erreichbar. Das ist nur in
  einem vertrauenswürdigen Netz in Ordnung. Das LiveDashboard und das Postfach unter
  `/dev` sind seit dem Login nur noch von `localhost` aus erreichbar, denn das Postfach
  enthält Anmeldelinks.
- Passkeys funktionieren mit dem selbstsignierten Zertifikat nicht in jedem Browser
  ([ADR 0005](0005-passkey-login.md)). Auf dem Handy ist dann der Magic Link nötig.
- Für den Betrieb (Deployment) braucht es später ein echtes Zertifikat, z. B. von
  Let's Encrypt.
