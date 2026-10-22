# 0002. Elixir, Phoenix and Ash as the technology base

- **Status:** Accepted
- **Date:** 2026-10-21

## Context

What's needed is a web application with a database, web interface and API for a private record
collection. Another important goal is to get to know Elixir, Phoenix and Ash.

## Decision

- **Elixir** (1.20 / OTP 29) as the language
- **Phoenix** as the web framework
- **Ash 3.x** as a declarative application framework: resources, actions, relationships and
  policies are described once, and database access, forms (AshPhoenix) and API (AshJsonApi)
  follow from them.
- The project is created and extended with **Igniter**.

## Alternatives considered

- **Phoenix with plain Ecto**: more manual work for forms, API and permissions. Unsuitable for
  the goal of learning Ash.

## Consequences

- Little boilerplate: API and forms mostly follow from the resource definitions.
- Ash has its own learning curve, and leaving "the Ash way" costs effort.
