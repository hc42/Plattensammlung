# 0013. Eigene Sammlungen, für andere sichtbar

- **Status:** Angenommen
- **Datum:** 2026-10-21
- **Ersetzt teilweise:** die „eine gemeinsame Sammlung“ aus [ADR 0005](0005-passkey-login.md)

## Kontext

Bisher teilten sich alle angemeldeten Benutzer eine Sammlung. Gewünscht ist: Jeder hat
seine eigene Sammlung und Wunschliste, und die anderen Benutzer können sie ansehen, ohne
dass es dafür eine Freigabe braucht.

## Entscheidung

- **Besitzer:** `Album.owner` (Pflicht), gesetzt per `relate_actor(:owner)` beim Anlegen.
  Exemplare gehören über ihr Album dazu. **Künstler** bleiben gemeinsam, das vermeidet
  Dubletten.
- **Sichtbarkeit:** Alle angemeldeten Benutzer (also Adressen aus `ALLOWED_EMAILS`) dürfen
  alle Alben und Exemplare lesen. Ohne Anmeldung ist nichts sichtbar.
- **Ändern:** nur der Besitzer. Policies: Update und Destroy am Album mit
  `owner_id == actor`, am Exemplar mit `album.owner_id == actor`. Ein Exemplar anlegen
  darf nur, wem das Album gehört (Check `AlbumOwnedByActor`).
- **Standardansicht = eigene Alben:** Die Listen-Actions (`search`, `collection`,
  `wishlist`, `by_barcode`, `duplicates`) und die Statistik zeigen ohne weiteres Argument
  die eigenen Alben (Preparation `ScopeToOwner`). Fremde Sammlungen werden ausdrücklich
  mit `owner_id` angefragt, auch über die API.
- **Anzeigename:** `User.display_name`, auf der Kontoseite gesetzt. Andere Benutzer sehen
  nur ID und Namen (Read-Action `collectors` wählt nur diese Felder aus). Die E-Mail bleibt
  privat.
- **Oberfläche:**
  - Seite „Sammler“ (`/collectors`) mit Sammlung und Wunschliste der anderen
    (`/collectors/:id`, `/collectors/:id/wishlist`).
  - Fremde Alben werden nur gelesen. Bearbeiten-Seiten leiten zurück (`Ownership`).
  - „Auf meine Wunschliste“ übernimmt die Albumdaten mit eigener Kopie der Cover-Datei.
  - Notizen und Kaufdatum fremder Exemplare werden nicht angezeigt.
- **Bestehende Daten:** Die Migration ordnet vorhandene Alben dem einen vorhandenen
  Benutzer zu. Gibt es Alben, aber nicht genau einen Benutzer, bricht sie mit einer
  Erklärung ab, statt zu raten.

## Betrachtete Alternativen

- **Freigaben pro Sammlung** (wer darf was sehen): nicht gewünscht, mehr Aufwand.
- **Öffentlicher Lese-Link ohne Anmeldung:** kann später ergänzt werden.
- **Künstler pro Benutzer:** führt zu Dubletten ohne erkennbaren Nutzen.

## Konsequenzen

- Jede Abfrage der Sammlung braucht einen Actor. Ohne Actor sind die Listen nicht mehr auf
  einen Besitzer beschränkt (nur für Seeds und Wartung mit `authorize?: false` relevant).
- Notizen und Kaufdatum sind nur in der Oberfläche verborgen. Über die API kann ein anderer
  angemeldeter Benutzer sie lesen. Sollen sie wirklich privat sein, braucht es Field Policies.
- Die Seeds legen die Beispielalben für die erste Adresse aus `ALLOWED_EMAILS` an.
