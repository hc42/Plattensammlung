# 0009. Gestaltung der JSON-API

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

[ADR 0004](0004-liveview-und-json-api.md) legt fest, dass es neben der LiveView-Oberfläche
eine JSON-API mit AshJsonApi und OpenAPI-Doku gibt. Offen war, wie die Endpunkte
aussehen und wie sie sich zu den vorhandenen Ash Actions verhalten.

## Entscheidung

- **Format:** JSON:API (`application/vnd.api+json`) über AshJsonApi 1.x, eingebunden unter
  `/api/json`. OpenAPI-Spezifikation unter `/api/json/open_api`, Swagger-UI unter
  `/api/json/swaggerui`.
- **Routen** werden in der Domain `Plattensammlung.Records` deklariert (`json_api do routes`).
  Jede Route ruft eine vorhandene Action auf, es gibt keine API-eigene Logik:

  | Methode und Pfad | Action |
  |---|---|
  | `GET /albums?query=…&status=collection\|wishlist` | `Album.search` |
  | `GET /albums/lookup?query=…` | `Album.lookup` (generische Action, liefert ein einfaches JSON-Array) |
  | `POST /albums/collection`, `POST /albums/wishlist` | `add_to_collection`, `add_to_wishlist` |
  | `PATCH /albums/:id/wanted`, `/unwanted` | `mark_wanted`, `unmark_wanted` |
  | `GET/PATCH/DELETE /albums/:id`, `GET /albums/:id/copies` | Standard-Actions, Beziehung |
  | `POST/GET/PATCH/DELETE /copies…`, `…/artists…` | Standard-Actions |

- Beziehungen lassen sich mit `?include=artist,copies` mitladen.
- Aggregate und Berechnungen (`owned`, `copy_count`, `discogs_url`) stehen in
  `default_fields` und sind damit Teil jeder Antwort.
- Cover-URLs sind relativ (`/covers/…`), solange sie lokal gespeichert sind.
- **Keine Authentifizierung**, bis der Login umgesetzt ist ([ADR 0005](0005-passkey-login.md)).
  Die Bearer-Auth, die AshJsonApi standardmäßig in die OpenAPI-Spezifikation schreibt, wird
  bis dahin entfernt.

## Betrachtete Alternativen

- **Eigene Phoenix-Controller mit einfachem JSON**: freier im Format, aber jede Route
  müsste von Hand geschrieben, validiert und dokumentiert werden.
- **AshGraphql**: flexibler für Clients, aber für eine Lern- und Sammlungs-App mehr als
  nötig. Kann später ergänzt werden.

## Konsequenzen

- Neue Actions werden mit einer Zeile in `routes` zur API. Die OpenAPI-Doku entsteht
  automatisch.
- AshJsonApi führt PATCH-Routen zuerst als atomares Update aus. AshPostgres kann dabei
  keine Aggregate laden, deshalb sind `mark_wanted`/`unmark_wanted` bewusst nicht atomar
  (Change als Funktion).
- Ohne Login ist die API mit `LAN=1` im ganzen WLAN schreibbar ([ADR 0008](0008-https-im-lan.md)).

## Nachtrag (2026-10-21)

Die Authentifizierung ist umgesetzt: API-Keys per `Authorization: Bearer …`, siehe
[ADR 0005](0005-passkey-login.md). Ohne Key antwortet die API mit 403. Die
OpenAPI-Spezifikation und die Swagger-UI bleiben ohne Key lesbar. Die Spezifikation
beschreibt wieder ein Bearer-Schema, sodass „Authorize“ in der Swagger-UI den API-Key
mitschickt.
