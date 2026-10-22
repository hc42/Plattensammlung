# 0020. Documentation in English

- **Status:** Accepted; the UI language rule superseded by [ADR 0021](0021-internationalization.md)
- **Date:** 2026-10-22
- **Supersedes:** the language rule of [ADR 0001](0001-use-adrs.md)

## Context

Code, identifiers and commit messages were in English from the start, the documentation (README,
ADRs, AGENTS.md, SECURITY.md, deploy guide) in German. Since the repository is on GitHub with an
English license and English automation (Dependabot, CodeQL, CI), the documentation is to be in
the same language as the source code.

## Decision

- All documentation is in English: README.md, AGENTS.md, SECURITY.md, `docs/adr/` (including
  template and index), `deploy/README.md` and comments in configuration files.
- Existing ADRs were translated, not rewritten: their content and dates stay; ADR file names got
  English slugs, and all links were updated.
- The user interface stays German. Where the documentation refers to UI texts, it quotes them in
  German (e.g. "Anmeldelink senden"), with an English explanation where helpful.
- The conversation with the owner stays German.

## Consequences

- New ADRs and documentation changes are written in English.
- German UI labels appear in quotes inside English text.
