# 0004. LiveView-Oberfläche und JSON-API

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

Die Sammlung soll im Browser bedienbar sein. Gleichzeitig sollen beide Ansätze
kennengelernt werden: serverseitige UI und API.

## Entscheidung

- **Phoenix LiveView** als Weboberfläche, Formulare über `AshPhoenix.Form`.
- **AshJsonApi** als JSON:API-Schnittstelle mit generierter OpenAPI-Doku (Swagger UI).
- Beide nutzen dieselben Ash Actions, die Logik existiert also nur einmal.

## Betrachtete Alternativen

- **Nur LiveView** oder **nur API**: wäre einfacher, verfehlt aber das Lernziel.
- **AshGraphql** statt AshJsonApi: wäre möglich und lässt sich später ergänzen.

## Konsequenzen

- Die Actions müssen so gestaltet sein, dass sie für UI und API gleichermaßen taugen.
- Die API braucht eigene Authentifizierung (Token), siehe ADR 0005.
