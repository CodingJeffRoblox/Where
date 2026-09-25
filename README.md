# Where

**Find what you're looking for.**

Where is a local-first, privacy-first layer across your digital life. You
know something exists — a file, a note, a task, a link — but not *where*.
Ask Where.

> Status: **Pre-alpha (Phase 0 → 1).** The Rust core proves the five
> prototype questions from the spec. The Flutter app is a first shell.

## What works today

| Spec §38 question | Status |
|---|---|
| Can Where index a user-selected folder? | ✅ `where_indexer` — metadata, BLAKE3 hash, MIME, incremental re-index, removes deleted files |
| Can it store objects locally? | ✅ `where_storage` — SQLite, versioned migrations, WAL |
| Can it search those objects quickly? | ✅ `where_search` — FTS5 prefix search, `kind:` filters, sub-millisecond on small sets |
| Can objects be connected? | ✅ `contains` / `involves` / `references`, shown in both directions |
| Can results be displayed clearly and quickly? | 🟡 Desktop app with grouped, highlighted results — awaiting first Windows build |

Search is relationship-aware: `website authentication` finds the task
*Fix Firebase authentication* because it lives in the *Website* project, and
the project itself shows up because it contains a match.

## Quick start (Windows)

Double-click **`start-where.bat`** in the repo folder. It will:

1. Check for Git, the Visual Studio C++ Build Tools, Rust and Flutter, and
   install anything missing (Windows may ask you to approve installers).
2. Remind you to switch on Windows **Developer Mode** if it's off (Flutter
   needs it for plugins).
3. Build the Rust core and the desktop app, then open Where.

It also adds **Where** to your desktop and Start menu. Run
`start-where.bat update` to pull the latest code and rebuild, or
`start-where.bat cli` for the command-line version. If the desktop app fails
to build, the script shows the error and falls back to the command line.
Detailed output is logged to `%LOCALAPPDATA%\where-tools\setup-log.txt`.

The first run downloads several GB of tools and can take 20–40 minutes.
Later runs take about a minute.

## Try it

```sh
cargo run -p where_cli -- demo                      # spec §39 example
cargo run -p where_cli -- add project Website
cargo run -p where_cli -- add task "Fix Firebase authentication" -p Website
cargo run -p where_cli -- index ~/Documents/website -p Website
cargo run -p where_cli -- search website auth
cargo run -p where_cli -- show Website
cargo run -p where_cli -- export -f md where.md
```

The CLI binary is `where-cli` (plain `where` clashes with `where.exe` on
Windows). The database lives in your platform's app-data folder; override
with `--db` or `WHERE_DB`.

## Layout

```
apps/where_flutter/     Flutter desktop app (dart:ffi → where_ffi)
crates/where_core/      Object + relationship model
crates/where_storage/   SQLite + FTS5 storage, export (json/md/csv/sqlite)
crates/where_search/    Query parsing, ranking, relationship context
crates/where_indexer/   Opt-in folder indexing
crates/where_ffi/       C ABI for the app (JSON in/out)
crates/where_cli/       Command-line prototype
docs/                   Spec, architecture decisions (docs/adr)
server/ plugins/        Reserved for Phase 3+ (sync) and Phase 6 (plugins)
```

## Principles

User-owned data · local-first · privacy-first · no mandatory AI ·
nothing is uploaded, deleted, or sent without explicit action.
See [docs/SPEC.md](docs/SPEC.md).

## Development

```sh
cargo test --all
cargo clippy --all-targets -- -D warnings
cargo fmt --all
```

Work is planned and tracked in Notion (Where → Roadmap). Reference the
Notion task in PR descriptions.
