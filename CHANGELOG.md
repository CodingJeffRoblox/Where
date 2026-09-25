# Changelog

All notable changes to Where are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and versions follow [Semantic Versioning](https://semver.org/).

## [Unreleased]

Planned next — see the Notion roadmap:

- First green Windows build of the desktop app in CI
- Search speed benchmark (100k objects, p95 < 50 ms)
- Global shortcut (Ctrl+Space) to open Where from anywhere
- Linking notes to files and people

## [0.1.0] — 2026-09-24 · Alpha prototype

The first version of Where: a local-first search engine and a desktop app
that connects your projects, tasks, notes and files.

### Added

**Desktop app (Windows)**
- Sidebar with Home, Projects, Tasks, Notes, Files and Settings.
- Search as you type, with results grouped by kind and matching words
  highlighted.
- Project cards with task progress; task checkboxes and
  Open / In progress / Done filters; note cards with previews.
- Detail pages: rename inline, notes save automatically, change task
  status, move items into a project, open or reveal files, and see
  everything connected.
- **Ctrl K** quick actions, plus Ctrl 1–5 and Ctrl , shortcuts.
- Settings: light / dark / system theme, indexed folders, a privacy panel
  showing what Where stores, and export.
- Subtle animations: fades, staggered lists, hover lift, animated
  checkboxes and counters.
- Folder indexing runs in the background so the window stays responsive.
- The program is called `Where.exe` and has its own icon.

**Search engine (Rust)**
- Object and relationship model: 16 kinds of object; *contains*,
  *involves* and *references* links.
- Local SQLite database with full-text search (FTS5) and versioned
  migrations.
- Relationship-aware search: "website authentication" finds the task
  *Fix Firebase authentication* inside the *Website* project.
- Opt-in folder indexing: name, path, size, dates, type and a BLAKE3
  fingerprint; re-indexing is incremental and removes deleted files.
- Export to JSON, Markdown, CSV or a copy of the database.
- `where-cli` command-line tool.

**Setup**
- `start-where.bat`: installs Git, the C++ Build Tools, Rust and Flutter
  if missing, builds everything, and opens Where. Adds desktop and Start
  menu shortcuts. `update` and `cli` modes. Logs details to a file and
  shows a clear summary if something fails.
- Continuous integration on Windows, macOS and Linux.

### Fixed
- The setup script now clears an out-of-date build cache (seen as
  `No target "where_flutter"`) and retries the app build once.

### Known limitations
- File *contents* are not searched yet — only names, paths and types.
- No sync, accounts, AI or activity tracking (all by design for now).
- Windows only for the desktop app; macOS and Linux come later.

[Unreleased]: https://github.com/CodingJeffRoblox/Where/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/CodingJeffRoblox/Where/releases/tag/v0.1.0
