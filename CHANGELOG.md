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

## [0.4.0] — 2026-09-25 · Loading screen and ready-to-run downloads

### Added
- **Loading screen.** Where opens straight away with an animated logo, a light
  circling it, a progress bar and each startup step ("Finding your library…",
  "Starting the search engine…"), then fades into the app. It uses your saved
  light/dark theme, and shows a clear message if something goes wrong.
- **Windows installer** — `Where-Setup-<version>-windows-x64.exe`: installs
  for your user without an admin prompt, adds a Start menu shortcut (desktop
  optional), an uninstaller, and opens Where when done. Your data is kept if
  you uninstall.
- **Linux AppImage** — one file that runs on most distributions — and a
  **.deb** for Ubuntu, Debian and Mint (installs to `/opt/where`, adds a
  menu entry and a `where` command). Both for x64 and ARM.
- The Windows downloads include the Microsoft C++ runtime, so Where starts on
  PCs without the Visual C++ Redistributable.

### Changed
- The Windows zip is now the *portable* download
  (`…-windows-x64-portable.zip`); the installer is the main one.
- Release notes list which file to pick for each computer.

## [0.3.0] — 2026-09-25 · Windows, Mac and Linux

### Added
- **Mac and Linux apps.** Where now builds as `Where.app` on macOS (Apple
  Silicon and Intel) and as `Where` on Linux (x64 and ARM), alongside
  `Where.exe` on Windows.
- **`start-where.sh`** (Mac and Linux) and **`start-where.command`**
  (double-click on a Mac): detects the operating system, processor and Linux
  distribution, installs what's missing (Xcode check and CocoaPods on Mac;
  build tools via apt, dnf, pacman or zypper on Linux; Rust; Flutter), builds
  the right app, adds it to Applications or the applications menu, and
  opens it.
- **Automatic release builds:** pushing a `v*` tag builds Windows x64, macOS
  universal (.dmg and .zip), Linux x64 and arm64 (.tar.gz) and the browser
  extension on GitHub, and publishes them as a Release with notes from this
  changelog.
- Linux `install.sh` adds Where to the applications menu (`--remove` undoes it).
- High-resolution app icon in `assets/icon/` used for Mac and Linux.

### Changed
- The app finds its engine inside each platform's package (next to
  `Where.exe`, in `Contents/Frameworks` on Mac, in `lib/` on Linux).
- On Mac, Where runs outside the App Store sandbox so it can re-index your
  chosen folders after a restart and accept the local browser connection.
- Scripts keep Unix line endings (`.gitattributes`) so they work after being
  committed from Windows.

### Known limitations
- Downloads aren't code-signed yet: Windows SmartScreen and macOS Gatekeeper
  will ask for confirmation the first time.
- Phones (Android, iOS) are not supported yet.

## [0.2.0] — 2026-09-25 · Save links from your browser

### Added
- **Where browser extension** for Chrome, Edge, Brave, Opera and Vivaldi
  (`browser-extension/`). Click the Where button or press **Alt+Shift+W** to
  save the page you're on with a title, a note and a project. Right-click a
  page or a link for *Save to Where*. Saving a page again updates it.
- **Browser connection** in the app: private to this computer
  (127.0.0.1:47771), and every browser must be approved once with an
  Allow / Deny prompt. Settings → Browser shows setup steps and lets you
  disconnect browsers.
- **Links** section (Ctrl 5): saved sites with clickable addresses, notes,
  projects, filter, copy and *Open in browser*. Sites show a letter avatar —
  no icons are downloaded, so nothing about your links leaves your computer.
- **Add link** by hand from Links, Home, a project page, or Ctrl K.
- Links appear in search, including by web address.

### Changed
- Files moved to Ctrl 6 (Links is Ctrl 5).
- `start-where.bat` copies the extension next to the app.
- Stricter `.gitignore`: build output, databases, exports, logs, keys,
  `.env` files and downloaded zips can't be committed by accident.

### Docs
- Added CODE_OF_CONDUCT, SECURITY, PRIVACY and SUPPORT, issue and pull
  request templates, CODEOWNERS, a docs index and ADR 5 (browser bridge).
- CONTRIBUTING explains how to keep private files and your email out of
  the repo.

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
- The setup script closes a running copy of Where before rebuilding, so
  Windows can replace `Where.exe` (previously `LNK1104: cannot open file`).

### Known limitations
- File *contents* are not searched yet — only names, paths and types.
- No sync, accounts, AI or activity tracking (all by design for now).
- Windows only for the desktop app; macOS and Linux come later (added in 0.3.0).

[Unreleased]: https://github.com/CodingJeffRoblox/Where/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/CodingJeffRoblox/Where/releases/tag/v0.4.0
[0.3.0]: https://github.com/CodingJeffRoblox/Where/releases/tag/v0.3.0
[0.2.0]: https://github.com/CodingJeffRoblox/Where/releases/tag/v0.2.0
[0.1.0]: https://github.com/CodingJeffRoblox/Where/releases/tag/v0.1.0
