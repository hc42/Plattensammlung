# 0021. Interface in English and German

- **Status:** Accepted
- **Date:** 2026-10-22
- **Partly supersedes:** "the user interface stays German" from [ADR 0020](0020-documentation-in-english.md)

## Context

Until now, all texts lived in German directly in the templates. The repository is public and
the code and documentation are English (ADR 0020), so others can only use the app if they read
German. The owner keeps using German. The interface should therefore support English as the
default and German as a translation, and follow the browser's language.

## Decision

- **Gettext** with English texts as msgids in the code (`gettext("Collection")`) and German
  translations in `priv/gettext/de/LC_MESSAGES/*.po`. English needs no translation file.
  Domains: `default` (interface), `errors` (validation messages from Ash, Ecto and our own
  validations), `auth` (texts of the AshAuthentication sign-in page, see `AuthOverrides`).
- **Choosing the language** (`PlattensammlungWeb.Locale`, plug and `on_mount` hook):
  1. the user's setting on the account page (`User.locale`: `"en"`, `"de"` or empty for
     "automatic"),
  2. otherwise the browser's `Accept-Language` header (with q-values),
  3. otherwise English.
  The plug keeps the browser language in the session so that LiveViews (which do not see the
  request headers after the first render) use the same language. `<html lang>` follows it.
- **Domain stays language-neutral:** Ash actions and the API return English texts or keys
  (statistics labels such as "Unknown", the fields of a match). The web layer translates them
  (`StatsLive.translate/1`, `AlbumComponents.field_label/1`). The JSON API stays English.
- **JavaScript** gets translated texts through `data-msg-*` attributes on the hook's element
  instead of its own translation files.
- **Magic link e-mails** are written in the language of the page they were requested on
  (`locale` in the action context); the user may not be signed in yet, so the account setting
  cannot apply.
- Dates are formatted per language (`AlbumComponents.format_date/1`: "Oct 22, 2026" or
  "22.10.2026").
- A test checks that every msgid of `default.pot` and `errors.pot` has a German translation that
  is neither empty nor fuzzy.

## Alternatives considered

- **Language in the URL** (`/de/…`): bookmarkable, but every route and every `~p` link would need
  the prefix, and with the optional path prefix (ADR 0018) the URLs get long. Not worth it for a
  small private app.
- **Only the browser language, no setting:** simpler, but someone with an English browser could
  not use the German interface.
- **German msgids** (keep the texts, add English translations): fewer changes now, but the code
  would mix languages and contradict ADR 0020.
- **Cldr (ex_cldr) for dates and numbers:** a large dependency for two date formats.

## Consequences

- New interface texts must use `gettext`/`ngettext` with an English msgid; after
  `mix gettext.extract --merge` the German translation goes into `de/LC_MESSAGES/default.po`.
  The completeness test fails otherwise.
- Texts in the `auth` domain are not extracted (they are strings in `AuthOverrides`); keep
  `de/LC_MESSAGES/auth.po` in sync by hand.
- Labels that depend on the language cannot be module attributes (they are evaluated at
  compile time); the forms build their optional field lists in a function.
- Further languages only need a new `.po` directory and an entry in `Locale.supported/0`, plus
  the `User.locale` constraint and the select on the account page.
