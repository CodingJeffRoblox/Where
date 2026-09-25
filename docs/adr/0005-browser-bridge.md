# 5. Browser extension talks to Where over a paired, loopback-only HTTP bridge

Date: 2026-09-25 · Status: Accepted

## Context
People want to save web pages (title, link, note, project) into Where from
their browser. Browser extensions can't call native code directly.

## Options
- **Native messaging:** strong, but needs a registry entry per browser and
  a separate host executable.
- **Custom URL scheme (`where://add?...`):** simple, but one-way (no project
  list, no "already saved") and any web page could trigger it.
- **Local HTTP server:** two-way and easy to debug.

## Decision
The app runs a small HTTP server on `127.0.0.1:47771` (loopback only).
- A browser pairs once: the extension asks, Where shows **Allow / Deny**,
  and on Allow returns a random 256-bit token stored per browser.
- Every call except `/v1/status` requires `X-Where-Token`.
- Requests with a web-page `Origin` are rejected, and no CORS headers are
  sent, so web pages can neither read nor write.
- Only `http(s)` URLs are stored; bodies are capped at 64 KB.
- Links are upserted by `url:<normalized address>` so saving twice updates.
- Pairing runs in the extension's background worker, because the popup closes
  when the user switches to Where to click Allow.

## Consequences
Works in every Chromium browser without extra install steps beyond loading
the extension. The port is fixed; if it's taken, Settings explains why the
browser can't connect. Revisit native messaging if the extension is
published to stores.
