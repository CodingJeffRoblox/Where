# Security policy

Where indexes people's files and keeps their notes, so security problems
matter a lot. Thank you for reporting them responsibly.

## Reporting a vulnerability

**Please don't open a public issue.** Instead use GitHub's private
reporting: go to the repo's **Security** tab → **Report a vulnerability**.

Include what you found, how to reproduce it, and what an attacker could do.
You'll get a reply within a week. Please give us a reasonable time to fix it
before sharing details publicly.

## Supported versions

Where is pre-release. Only the latest version on `main` gets fixes.

| Version | Supported |
|---|---|
| 0.2.x | ✅ |
| < 0.2 | ❌ |

## What's in scope

- **Browser connection** (`apps/where_flutter/lib/src/browser_bridge.dart`
  and `browser-extension/`): it must only accept the paired extension, only
  on 127.0.0.1, and never let a web page read or write data.
- **Folder indexing** (`crates/where_indexer`): it must only read folders the
  user chose and must never modify or delete files.
- **Local database and exports**: no data leaves the device unless the user
  exports it.
- **Setup script** (`start-where.bat`): what it downloads and runs.

## Design rules

See the security model in [the spec, §26](docs/SPEC.md#26-security-model):
least privilege, explicit permissions, secure defaults, minimal telemetry.
Where currently sends **no** telemetry.
