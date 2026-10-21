# 0001. Architekturentscheidungen als ADRs festhalten

- **Status:** Angenommen
- **Datum:** 2026-10-21

## Kontext

Das Projekt entsteht schrittweise im Dialog mit einem KI-Assistenten. Damit später noch
nachvollziehbar ist, *warum* etwas so gebaut wurde, sollen Entscheidungen schriftlich
festgehalten werden.

## Entscheidung

Architekturentscheidungen werden als kurze Markdown-Dateien in `docs/adr/` festgehalten,
im Stil von Michael Nygard, auf Deutsch und fortlaufend nummeriert. README.md, AGENTS.md
und die ADRs werden bei Änderungen ohne gesonderte Aufforderung aktualisiert.

## Konsequenzen

- Entscheidungen sind mit ihrer Begründung nachvollziehbar.
- Eine geänderte Entscheidung bekommt einen neuen ADR. Der alte bleibt als Historie
  erhalten und wird als „Ersetzt“ markiert.
