# 0018. Optionaler Pfad-Präfix

- **Status:** Angenommen
- **Datum:** 2026-10-22

## Kontext

Die App soll wahlweise auch unter einem Pfad einer gemeinsam genutzten Domain laufen, z. B.
`https://cloud.example.com/plattensammlung`, statt unter einer eigenen (Sub-)Domain. Ohne
Angabe soll alles wie bisher unter `/` laufen.

## Entscheidung

- **Der Proxy schneidet das Präfix ab** (nginx `location /plattensammlung/ { proxy_pass
  http://app/; }`). Die App selbst bedient weiterhin alles unter `/`: Router, statische
  Dateien, Cover und der LiveView-Socket bleiben unverändert.
- **Die App kennt das Präfix** über die optionale Umgebungsvariable `PHX_PATH`
  (`runtime.exs` → `url: [path: …]` des Endpoints) und setzt es vor jeden Link, den sie
  erzeugt:
  - Verified Routes (`~p`) und statische Pfade nehmen es automatisch.
  - JavaScript liest es aus `<meta name="base-path">` (`assets/js/app_path.js`): LiveView-
    Socket und Passkey-Anfragen.
  - Lokale Cover (`/covers/…` in der Datenbank) bekommen es beim Anzeigen
    (`Endpoint.path/1`); gespeichert wird weiter ohne Präfix.
  - Absolute URLs: `PublicUrl.base_url/1` bleibt Schema + Host (für WebAuthn-Origin und
    `~p`-Links in E-Mails), `PublicUrl.url/2` ergänzt das Präfix (JSON-LD, OpenAPI-Server).
  - Die Swagger-UI lädt die Spezifikation über einen relativen Pfad.

## Betrachtete Alternativen

- **Die App entfernt das Präfix selbst:** Phoenix ordnet den LiveView-Socket vor allen
  eigenen Plugs zu, und `socket "/live"` ist zur Compile-Zeit festgelegt. Das Präfix wäre
  nicht mehr zur Laufzeit konfigurierbar.
- **Präfix fest in Router und Assets einbauen:** dann liefe die App nur noch unter diesem
  Pfad, auch in der Entwicklung.

## Konsequenzen

- Mit Präfix braucht nginx-proxy-manager eine eigene `location` mit Websocket-Headern
  (Anleitung in `deploy/README.md`).
- Neue Pfade in JavaScript immer über `appPath()`, neue absolute URLs über
  `PublicUrl.url/2`; nie `/…` fest in JS oder Strings schreiben.
- Die API liefert `cover_url` weiter ohne Präfix (`/covers/…`, relativ zur App).
- Passkeys gelten für die ganze Domain, nicht nur für den Pfad.
