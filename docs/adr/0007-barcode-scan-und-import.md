# 0007. Barcode-Scan und Import aus Discogs und MusicBrainz

- **Status:** Angenommen (Import umgesetzt am 2026-10-21, Kamera-Scan folgt)
- **Datum:** 2026-10-21

## Kontext

Erfassen soll wenig Arbeit machen (siehe [ADR 0006](0006-datenmodell.md)). Ideal ist:
Barcode scannen, und Artist, Titel, Jahr, Genres und Cover sind ausgefüllt. Der Benutzer
soll dabei **nie aus vielen Pressungsvarianten wählen müssen**.

Wichtige Beobachtung: Ein **Barcode bezeichnet bereits eine konkrete Pressung**. Über
diese lässt sich automatisch das zugehörige Album ermitteln (Discogs „Master“,
MusicBrainz „Release Group“). Die Variantenauswahl entfällt also.

## Entscheidung

**Erfassungswege**, alle führen zu einem vorausgefüllten Formular, das nur noch
bestätigt wird:

1. **Barcode scannen** mit der Handy- oder Laptop-Kamera im Browser
   (`BarcodeDetector`-API, wo verfügbar, sonst eine JS-Bibliothek wie ZXing).
   Barcode-Ziffern eintippen und USB-Handscanner (die sich wie eine Tastatur verhalten)
   funktionieren ebenfalls.
2. **Suche nach Artist und Titel**, für ältere Platten ohne Barcode (meist vor ca. 1980).
   Treffer werden auf **Album-Ebene** angezeigt, nicht als Pressungen.
3. **Manuell**: nur Artist und Titel.

**Ablauf beim Barcode:**
Barcode → Pressung suchen → zugehöriges Album ermitteln → Artist, Titel,
Erscheinungsjahr, Genres und Cover übernehmen. Die IDs von Pressung und Album werden
gespeichert, daraus entstehen Links zu Discogs. Gibt es mehrere Treffer für einen
Barcode, wird automatisch der erste genommen. Die Pressungsdetails sind ohnehin
optional.

**Datenquellen** hinter einem gemeinsamen Elixir-Behaviour (`Lookup`), damit Quellen
austauschbar sind:

| Quelle | Zugang | Stärken |
|---|---|---|
| **Discogs API** | Kostenloses persönliches Token (Discogs-Konto → Einstellungen → Developers), 60 Anfragen/Minute | Sehr vollständig für Vinyl, Barcode-Suche, Master/Release |
| **MusicBrainz** + **Cover Art Archive** | Ohne Konto, max. 1 Anfrage/Sekunde, eigener User-Agent nötig | Offene Daten, Cover in guter Qualität |

Zuerst wird Discogs gefragt, MusicBrainz dient als Rückfallebene und ergänzt fehlende
Cover. Cover werden **lokal gespeichert**, damit die Sammlung ohne die externen Dienste
vollständig bleibt.

HTTP-Aufrufe erfolgen mit `Req`. Die Suche ist die generische Ash Action `Album.lookup`.
Sie liefert die Embedded Resource `LookupResult`, damit LiveView und JSON-API sie
gleichermaßen nutzen können. Übernommen wird ein Treffer über die vorhandenen Actions
`add_to_collection` bzw. `add_to_wishlist`.

### Umsetzungsdetails

- Ein Eingabefeld für alles: 8–14 Ziffern (Leerzeichen und Bindestriche erlaubt) gelten
  als Barcode, alles andere als Textsuche.
- Textsuche: Discogs sucht *Master*, MusicBrainz *Release Groups* (Modus `dismax`, findet
  Artist und Titel zusammen). Gleiche Alben (Artist und Titel normalisiert) erscheinen
  nur einmal, Discogs zuerst, weil es besser nach Bekanntheit sortiert.
- Barcode bei Discogs: Release suchen, danach den Master laden. Der Master liefert das
  Originaljahr und die Genres, der Release die Pressungsdetails für die Copy.
- Liefert eine Quelle einen Fehler, wird die nächste gefragt. Ein Fehler wird nur
  gemeldet, wenn keine Quelle antwortet.
- Ein Barcode wird zusätzlich lokal geprüft: „Genau diese Pressung hast du schon“
  (Read Action `Album.by_barcode`, Index auf `copies.barcode`).
- Cover-Download vor der Datenbank-Transaktion, mit kurzen Timeouts (4 s Verbindung,
  8 s Antwort). Bei Fehlern bleibt die Remote-URL stehen.
- Der Lookup läuft in der LiveView asynchron (`start_async`).

## Betrachtete Alternativen

- **Nur Discogs**: einfacher, aber abhängig von einem Konto und Token.
- **Pressung im Dialog auswählen lassen**: genau das soll vermieden werden.

## Konsequenzen

- Für die Kamera braucht der Browser einen sicheren Kontext. Auf dem Mac reicht
  `localhost`, **vom Handy im WLAN aus ist HTTPS nötig** (z. B. ein lokales Zertifikat
  mit `mkcert` oder `mix phx.gen.cert`).
- Safari unterstützt `BarcodeDetector` nicht vollständig, deshalb ist eine
  JS-Bibliothek als Rückfall nötig.
- Das Discogs-Token wird als Umgebungsvariable (`DISCOGS_TOKEN`) konfiguriert, nie im
  Repository gespeichert.
- Die Nutzungsbedingungen von Discogs (Quellenangabe, Rate Limits) sind einzuhalten.
  Für eine private Sammlung ist das unproblematisch.
