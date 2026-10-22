# 0017. Rate Limits

- **Status:** Angenommen
- **Datum:** 2026-10-22

## Kontext

Im Betrieb ist die App aus dem Internet erreichbar. Bisher gab es keine Rate Limits:

- „Anmeldelink senden“ ist ohne Anmeldung erreichbar. In einer Schleife abgeschickt,
  überflutet es das Postfach einer freigeschalteten Adresse und kann den SMTP-Zugang beim
  Mail-Anbieter drosseln oder sperren lassen.
- MusicBrainz erlaubt etwa eine Anfrage pro Sekunde pro IP-Adresse; eine Suche im Import
  löst mehrere Anfragen kurz hintereinander aus. Die App wiederholte nur bei 503.
- Hinter nginx-proxy-manager sah die App als Absender nur den Proxy.

Angemeldeten Benutzern wird vertraut (Freigabeliste); ihre Seiten und die API brauchen
keine Limits. Passkeys und API-Keys sind gegen Durchprobieren kryptografisch sicher.

## Entscheidung

- **Bibliothek Hammer** mit ETS-Backend (`Plattensammlung.RateLimit`): im Arbeitsspeicher,
  kein weiterer Dienst. Die Zähler beginnen nach einem Neustart neu.
- **Anmeldelinks** (`Accounts.RequestMagicLink`, ersetzt den `run` der Action
  `request_magic_link`): höchstens 3 pro Adresse in 15 Minuten und 10 pro IP-Adresse pro
  Stunde (`config :plattensammlung, :magic_link_limits`). Darüber wird nichts gesendet, die
  Antwort bleibt gleich. Die IP-Adresse kommt über den Action-Kontext (`client_ip`) von der
  Anmeldeseite.
- **Client-IP** (`PlattensammlungWeb.ClientIp`): bevorzugt `X-Forwarded-For`, und zwar den
  letzten Eintrag (den hängt der Proxy selbst an; frühere Einträge kommen vom Client), sonst
  die Adresse der Verbindung. Als Plug im Endpoint (`conn.remote_ip`), für LiveViews über
  `connect_info` (`:peer_data`, `:x_headers`).
- **MusicBrainz** (`Lookup.Throttle`): Alle Anfragen der App halten mindestens 1 Sekunde
  Abstand (`:musicbrainz_interval_ms`). Ein Req-Request-Step wartet auf seinen Zeitschlitz;
  der GenServer vergibt nur die Schlitze, gewartet wird im aufrufenden Prozess.
- **Proxy:** Ein optionaler `limit_req`-Schnipsel für nginx-proxy-manager steht in
  `deploy/README.md` (10 Anfragen pro Sekunde pro IP, Spitzen bis 50).

## Betrachtete Alternativen

- **`X-Forwarded-For` nur von bekannten Proxy-Adressen** (`TRUSTED_PROXIES`): sicherer gegen
  gefälschte Header, aber mehr Konfiguration. Da Port 4000 nur im LAN erreichbar ist, reicht
  der letzte Eintrag.
- **Limits nur im Proxy:** NPM kennt die Bedeutung der Anfragen nicht (ein Anmeldelink ist
  über die LiveView-Verbindung nur eine Websocket-Nachricht).
- **Rate Limits für angemeldete Benutzer und die API:** nicht nötig, ihnen wird vertraut.

## Konsequenzen

- Eine Importsuche dauert mit MusicBrainz ein paar Sekunden länger, bleibt aber innerhalb
  der Regeln.
- Wer Port 4000 direkt erreicht, kann `X-Forwarded-For` fälschen und so das Limit pro IP
  umgehen; das Limit pro Adresse gilt trotzdem.
- Mehrere App-Instanzen hätten getrennte Zähler und Drosseln (derzeit gibt es nur eine).
- Tests setzen hohe Limits und keinen MusicBrainz-Abstand (`config/test.exs`).
