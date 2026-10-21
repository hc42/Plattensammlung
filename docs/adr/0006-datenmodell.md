# 0006. Datenmodell der Sammlung

- **Status:** Vorgeschlagen (in Diskussion)
- **Datum:** 2026-10-21

## Kontext

Erfasst werden sollen Schallplatten mit allgemeinen Angaben (Titel, Artist, Label, Jahr)
und Angaben zum eigenen Exemplar (Zustand, Preis, Lagerort). Dieselbe Pressung kann
mehrfach vorhanden sein. Ein späterer Import aus Discogs soll möglich bleiben.

## Entscheidung (Entwurf)

Ash-Domain `Plattensammlung.Records` mit diesen Resources:

```
Artist ──< Release >── Label
              │
              ├──< Copy
              └──< Track
```

| Resource | Bedeutung | Felder (Entwurf) |
|---|---|---|
| **Artist** | Künstler oder Band | Name, Sortiername („Beatles, The“), Land |
| **Label** | Plattenfirma | Name |
| **Release** | Eine bestimmte Veröffentlichung oder Pressung | Titel, Artist, Label, Katalognummer, Jahr, Format, Pressungsland, Genre, Cover |
| **Copy** | Ein konkretes eigenes Exemplar | Release, Zustand Platte, Zustand Hülle, Kaufdatum, Kaufpreis, Lagerort, Notizen |
| **Track** | Titel auf der Platte (optional) | Release, Position („A1“), Titel, Dauer |

Beispiel: *Abbey Road* (Apple Records, PCS 7088, UK 1969) ist **ein Release**. Besitzt
man es zweimal, gibt es **zwei Copies** mit eigenem Zustand und Preis.

## Offene Fragen

1. **Mehrere Artists pro Release?** Für Kollaborationen („Artist A & Artist B“) und
   Sampler („Various Artists“) bräuchte es eine Viele-zu-viele-Beziehung.
2. **Genre:** feste Liste oder freie Tags? Eins oder mehrere pro Release?
3. **Format-Details:** Größe (12"/10"/7"), Geschwindigkeit (33⅓/45/78), Anzahl Platten
   (2LP), Vinylfarbe, limitiert, Picture Disc?
4. **Zustandsskala:** Goldmine (M, NM, VG+, VG, G+, G, F, P), getrennt für Platte und Hülle?
5. **Lagerort:** Freitext oder eigene Resource (Regal → Fach)?
6. **Tracks:** gleich von Anfang an oder später?
7. **Album vs. Pressung:** Soll es (wie Discogs’ „Master Release“) eine Ebene „Album“
   über den Pressungen geben, z. B. für Original und Reissue von *Abbey Road*?
8. **Status eines Exemplars:** nur „im Besitz“ oder auch Wunschliste, verkauft, verliehen
   (an wen)?
9. **Wert:** nur Kaufpreis oder auch geschätzter aktueller Wert? Währung nur EUR?
10. **Identifikatoren:** Barcode, Discogs-ID, Matrix/Runout?

## Konsequenzen

Werden nach Klärung der offenen Fragen ergänzt.
