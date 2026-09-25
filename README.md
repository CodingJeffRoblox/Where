<div align="center">

<img src="apps/where_flutter/windows/runner/resources/app_icon.png" width="96" alt="Where icon">

# Where

**Find what you're looking for.**

Your files, notes, tasks and projects, connected and searchable in one place.
Local-first. Private by default. No account needed.

[![Version](https://img.shields.io/badge/version-0.1.0_alpha-4F5BD5)](CHANGELOG.md)
[![CI](https://github.com/CodingJeffRoblox/Where/actions/workflows/ci.yml/badge.svg)](https://github.com/CodingJeffRoblox/Where/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6)
![Rust](https://img.shields.io/badge/core-Rust-B7410E)
![Flutter](https://img.shields.io/badge/app-Flutter-02569B)
![Local-first](https://img.shields.io/badge/data-stays_on_your_device-2E7D32)

</div>

---

## Why Where?

File Explorer shows you **where a file is**. Where shows you **everything
about a piece of work**: its files, tasks, notes and links, in one search.

| You want to… | File Explorer | Where |
|---|---|---|
| Find a file by name | ✅ | ✅ |
| See the tasks and notes that go with a folder | ❌ | ✅ |
| Search "website login" and get the task, the note *and* the code folder | ❌ | ✅ |
| Find something without remembering which app or folder it's in | ❌ | ✅ |
| Keep everything offline and private | ✅ | ✅ |

Where doesn't replace your apps or move your files. It sits on top of them and
connects them. It isn't the first tool to link notes and projects
(Notion, Capacities and Anytype do too); what's different is combining that
with **your real files**, fully offline. See
[the spec](docs/SPEC.md#33-competitive-landscape) for the honest comparison.

## Features

- **Search everything as you type.** Results are grouped by kind with the
  matching words highlighted, and search follows connections:
  *"website authentication"* finds the task *Fix Firebase authentication*
  because it's inside the *Website* project.
- **Projects** collect tasks, notes and folders, with a progress bar.
- **Tasks** with checkboxes, *In progress* status and filters.
- **Notes** that save as you type and can belong to a project.
- **Files**: index only the folders you choose. Where never moves,
  changes or uploads your files.
- **Ctrl K** for quick actions: create, jump anywhere, index, export,
  switch theme.
- **Privacy panel** that shows exactly what Where stores. Sync, AI and
  activity tracking are all off.
- **Export everything** to JSON, Markdown, CSV or a database copy.
- Light and dark themes, full keyboard control, subtle animations.

## Quick start (Windows)

1. Download or clone this repo.
2. Double-click **`start-where.bat`**.

That's it. The script:

- installs anything missing (Git, Visual Studio C++ Build Tools, Rust,
  Flutter; Windows may ask you to approve installers),
- reminds you to turn on **Developer Mode** if it's off,
- builds the search engine and the app, opens **Where**, and adds it to your
  desktop and Start menu.

The first run downloads several GB of tools and can take 20–40 minutes.
Later runs take about a minute.

| Command | What it does |
|---|---|
| `start-where.bat` | Set up if needed, build, open Where |
| `start-where.bat update` | Get the latest code from GitHub first |
| `start-where.bat cli` | Open the command-line version |

If something goes wrong, the script shows the last lines of its log. The full
log is at `%LOCALAPPDATA%\where-tools\setup-log.txt`.

## Keyboard shortcuts

| Keys | Action |
|---|---|
| `Ctrl K` | Quick actions and search |
| `Ctrl 1` – `Ctrl 5` | Home, Projects, Tasks, Notes, Files |
| `Ctrl ,` | Settings |
| `↑` `↓` `Enter` | Move through results and open |
| `Esc` | Close a dialog |

## Command line

```sh
where-cli demo                                   # the spec §39 example
where-cli add project Website
where-cli add task "Fix Firebase authentication" -p Website
where-cli index ~/Documents/website -p Website
where-cli search website auth
where-cli show Website
where-cli export -f md where.md
```

Run from source with `cargo run -p where_cli -- <command>`. The tool is named
`where-cli` because plain `where` clashes with Windows' built-in `where.exe`.

## How it works

```
apps/where_flutter ──dart:ffi──► where_ffi ──► where_search ──► where_storage (SQLite + FTS5)
                                                     ▲                  ▲
                          where_cli ─────────────────┘      where_indexer ┘
                                                     all built on where_core
```

| Folder | What's inside |
|---|---|
| `apps/where_flutter/` | The desktop app (Flutter) |
| `crates/where_core/` | Objects and relationships |
| `crates/where_storage/` | SQLite storage, full-text index, export |
| `crates/where_search/` | Query parsing, ranking, relationship-aware matching |
| `crates/where_indexer/` | Opt-in folder indexing |
| `crates/where_ffi/` | The bridge between the app and the engine |
| `crates/where_cli/` | Command-line tool |
| `docs/` | [Product spec](docs/SPEC.md) and [architecture decisions](docs/adr/) |

## Status

**v0.1.0 — alpha prototype.** See the [changelog](CHANGELOG.md).

| Spec §38 question | Status |
|---|---|
| Can Where index a folder you choose? | ✅ |
| Can it store objects locally? | ✅ |
| Can it search them quickly? | ✅ sub-millisecond on small sets |
| Can objects be connected? | ✅ |
| Can results be shown clearly and quickly? | 🟡 desktop app built; first Windows build in progress |

**Next up:** a green Windows build in CI, a search speed benchmark, a global
Ctrl+Space shortcut, and linking notes to files and people. Later: sync,
integrations (GitHub, Google Drive, calendar), optional AI search, plugins.

## Principles

Your data is yours · works offline · private by default · no required AI ·
never deletes your files, sends messages or uploads anything without you
asking.

## Development

```sh
cargo test --all
cargo clippy --all-targets -- -D warnings
cargo fmt --all
```

See [CONTRIBUTING.md](CONTRIBUTING.md). Work is planned in Notion
(Where → Roadmap & Tasks); link the Notion task in each pull request.
