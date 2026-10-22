# 0025. Browser tests with PhoenixTest.Playwright

- **Status:** Accepted
- **Date:** 2026-10-23

## Context

More and more of the interface lives in JavaScript: barcode scanner, passkeys, cover colours,
the remembered list view, the back link, view transitions, the service worker. The tests
(`Phoenix.LiveViewTest`) only see the server side: a bug like "back from the album page loses
the list view" passed all of them and was only found by hand.

## Decision

- **PhoenixTest.Playwright** (`phoenix_test_playwright`, test only): ExUnit tests that drive a
  real Chromium through Playwright, in the same style as the other tests and with the same
  fixtures. The Playwright npm package is a pinned dev dependency in `assets/package.json`.
- **Database:** every test keeps its own Ecto sandbox transaction, and the tests stay `async`.
  The browser sends the sandbox id in its user agent; `Phoenix.Ecto.SQL.Sandbox` in the endpoint
  and the `on_mount` hook `LiveSandbox` (prepended in both live sessions, before
  AshAuthentication loads the user) let the server processes join it. Only compiled in when
  `config :plattensammlung, sql_sandbox: true` (test env).
- **Server in tests** on port 4012 (`server: true`), so it doesn't clash with dev (4000) or a
  manual instance (4002). `config/runtime.exs` no longer sets the port in the test env.
- **Signing in:** a session cookie with a stored token (`BrowserHelpers.sign_in/2`), no magic link.
- They run with every `mix test` (and so in `mix precommit` and CI), not as an opt-in suite that
  would be forgotten. `mix test` builds the assets first; `mix setup` installs Chromium (not in
  the release image); CI also installs Chromium's system libraries.
- Tests live in `test/plattensammlung_web/browser/` and cover what only a browser can show:
  remembered list view and back link, the background tint, the "⋯" menu with confirmation
  dialogs, merging, deleting the account, the service worker, starting the camera.

## Alternatives considered

- **Wallaby:** also Elixir, but drives Chrome through ChromeDriver, whose version has to match
  the browser.
- **Playwright Test in JavaScript:** a second test suite in another language with its own way of
  creating data and no sandbox per test.
- **Only tagged, opt-in browser tests:** faster `mix test`, but they would rarely run.

## Consequences

- `mix test` needs Node and Chromium; after cloning, `mix setup` installs both.
- Passkeys can't be tested in the browser: a virtual WebAuthn authenticator needs the Chrome
  DevTools protocol, which the library doesn't expose. The WebAuthn protocol stays covered by
  the server-side tests with a software authenticator.
- Offline behaviour can't be simulated either; the tests check that the service worker is
  installed and has cached the offline page.
- Pages that look things up on Discogs/MusicBrainz (import, matching) need the shared Req stub
  (`async: false`) before they can be tested in the browser.
- New JavaScript features get a browser test; LiveView assertions only for what the server renders.
