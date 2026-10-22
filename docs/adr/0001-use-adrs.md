# 0001. Record architecture decisions as ADRs

- **Status:** Accepted; the language rule is superseded by [ADR 0020](0020-documentation-in-english.md)
- **Date:** 2026-10-21

## Context

The project is built step by step in conversation with an AI assistant. So that it stays
clear later *why* something was built a certain way, decisions are to be written down.

## Decision

Architecture decisions are recorded as short Markdown files in `docs/adr/`, in Michael
Nygard's style, in German and numbered consecutively. README.md, AGENTS.md and the ADRs are
updated with every change without being asked.

## Consequences

- Decisions can be traced together with their reasons.
- A changed decision gets a new ADR. The old one stays as history and is marked "Superseded".
