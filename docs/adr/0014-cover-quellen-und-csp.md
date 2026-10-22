# 0014. Cover-Quellen und Content-Security-Policy

- **Status:** Angenommen
- **Datum:** 2026-10-22

## Kontext

Seit Sammlungen für andere Benutzer sichtbar sind ([ADR 0013](0013-eigene-sammlungen.md)),
zeigt die App Daten eines Benutzers im Browser eines anderen. Eine Prüfung nach den OWASP
Top 10 ergab:

- **Escaping ist in Ordnung:** HEEx escapt alle Ausgaben, es gibt kein `raw`, die JS-Hooks
  setzen kein `innerHTML`, Links entstehen aus geprüften IDs.
- **Zugriffskontrolle (A01):** `cover_url` ließ sich über die API auf einen lokalen Pfad
  `/covers/…` setzen, auch auf die Datei eines anderen Benutzers. Beim Löschen des eigenen
  Albums (oder schon beim Fehlschlag der Action) wurde dann dessen Datei gelöscht.
- **SSRF (A10):** Der Server lud jede `http(s)`-Adresse aus `cover_url` herunter, auch im
  lokalen Netz (NAS-Oberfläche, Router). War die Antwort ein Bild, war es danach abrufbar.
- Remote-URLs, deren Download fehlschlug, blieben gespeichert und wurden von den Browsern
  anderer Benutzer geladen (Tracking-Pixel).
- Es gab keine Content-Security-Policy als zweite Absicherung.

## Entscheidung

- **Erlaubte Cover-Quellen:** `config :plattensammlung, :cover_hosts`, derzeit
  `i.discogs.com`, `coverartarchive.org` und `archive.org` (jeweils mit Subdomains, nur
  https). `Covers.allowed_url?/1` prüft das.
- **Download:** nur von erlaubten Hosts. Weiterleitungen folgt die App selbst (höchstens
  drei), jede Station muss erlaubt sein.
- **Eingaben:** Die Validation `CoverSource` lässt für `cover_url` nur leer oder eine
  erlaubte https-URL zu (in `add_to_collection`, `add_to_wishlist`, `update` und nach
  `ApplyMatch` in `apply_match`). Lokale Pfade setzt nur die App selbst: Download, Upload und
  die neue Action `copy_to_wishlist` („Auf meine Wunschliste“), die die Cover-Datei
  dupliziert. Eigene Bilder kommen über den Upload.
- **Aufräumen:** Schlägt eine Action fehl, löscht sie nur die Datei, die sie selbst angelegt
  hat (`changeset.context[:stored_cover]`), nie einen Pfad aus der Eingabe.
- **Content-Security-Policy** (`PlattensammlungWeb.Plugs.ContentSecurityPolicy`, in der
  `:browser`-Pipeline): Skripte nur von der App, das Theme-Skript im Root-Layout mit
  Nonce pro Anfrage; Bilder von der App, `data:`/`blob:` und den Cover-Quellen;
  `style`-Attribute erlaubt, `<style>`-Elemente nicht; keine Frames, keine Plugins,
  Formulare nur an die App. `/dev` (LiveDashboard, Postfach) läuft ohne CSP.

## Betrachtete Alternativen

- **Private Adressen sperren statt Hosts erlauben:** DNS-Rebinding, IPv6- und
  Weiterleitungs-Tricks machen eine Sperrliste fehleranfällig. Cover kommen ohnehin nur
  aus dem Import, also von bekannten Quellen.
- **`cover_url` gar nicht mehr annehmen:** würde die API-Übernahme aus Discogs/MusicBrainz
  erschweren.
- **CSP mit `'unsafe-inline'` für Skripte:** nähme der CSP den größten Teil ihres Nutzens.

## Konsequenzen

- Eine neue Import-Quelle mit eigenen Bild-Servern muss in `:cover_hosts` eingetragen werden,
  sonst werden ihre Cover abgelehnt. Die CSP übernimmt die Liste automatisch.
- Neue Inline-Skripte brauchen `nonce={assigns[:csp_nonce]}`, inline `<style>` geht nicht.
- Fremde Bild-URLs lassen sich nicht mehr eintragen; dafür gibt es den Upload.
