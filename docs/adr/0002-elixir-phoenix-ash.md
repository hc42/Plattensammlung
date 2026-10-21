# 0002. Elixir, Phoenix und Ash als Technologiebasis

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

Gebraucht wird eine Web-Anwendung mit Datenbank, Weboberfläche und API für eine private
Plattensammlung. Ein wichtiges Ziel ist auch, Elixir, Phoenix und Ash kennenzulernen.

## Entscheidung

- **Elixir** (1.20 / OTP 29) als Sprache
- **Phoenix** als Web-Framework
- **Ash 3.x** als deklaratives Anwendungs-Framework: Resources, Actions, Relationships
  und Policies werden einmal beschrieben, und daraus entstehen Datenbankzugriff,
  Formulare (AshPhoenix) und API (AshJsonApi).
- Projekt wird mit **Igniter** angelegt und erweitert.

## Betrachtete Alternativen

- **Phoenix mit reinem Ecto**: mehr Handarbeit für Formulare, API und Berechtigungen.
  Für das Lernziel „Ash“ ungeeignet.

## Konsequenzen

- Wenig Boilerplate: API und Formulare entstehen größtenteils aus den Resource-Definitionen.
- Ash hat eine eigene Lernkurve, und Abweichungen vom „Ash-Weg“ kosten Aufwand.
