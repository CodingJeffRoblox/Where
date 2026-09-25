<div align="center">

<img src="apps/where_flutter/windows/runner/resources/app_icon.png" width="96" alt="Where icon">

# Where

**Find what you're looking for.**

Your files, notes, tasks and projects, connected and searchable in one place.
Local-first. Private by default. No account needed.

[![Version](https://img.shields.io/badge/version-0.4.0_alpha-4F5BD5)](CHANGELOG.md)
[![CI](https://github.com/CodingJeffRoblox/Where/actions/workflows/ci.yml/badge.svg)](https://github.com/CodingJeffRoblox/Where/actions/workflows/ci.yml)
![Platform](https://img.shields.io/badge/platform-Windows_%7C_macOS_%7C_Linux-0078D6)
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
- **Links** from your browser: click the Where button (or Alt+Shift+W) on
  any page to save it with a title, a note and a project. Addresses are
  clickable and searchable. [Browser extension →](browser-extension/)
- **Files**: index only the folders you choose. Where never moves,
  changes or uploads your files.
- **Ctrl K** for quick actions: create, jump anywhere, index, export,
  switch theme.
- **Privacy panel** that shows exactly what Where stores. Sync, AI and
  activity tracking are all off.
- **Export everything** to JSON, Markdown, CSV or a database copy.
- Light and dark themes, full keyboard control, subtle animations.

## Download

Get the file for your computer from the
[latest release](https://github.com/CodingJeffRoblox/Where/releases/latest):

| Your computer | Download | Then |
|---|---|---|
| **Windows** 10 / 11 | `Where-Setup-…-windows-x64.exe` | Run it. Where is added to the Start menu. |
| Windows, no install | `Where-…-windows-x64-portable.zip` | Unzip, run `Where.exe` |
| **Mac** (Apple Silicon or Intel) | `Where-…-macos-universal.dmg` | Open it, drag Where to Applications |
| **Linux** (any distro) | `Where-…-linux-x64.AppImage` | `chmod +x` the file, then run it |
| Ubuntu / Debian / Mint | `Where-…-linux-x64.deb` | `sudo apt install ./Where-…-linux-x64.deb` |
| Linux on ARM | `…-linux-arm64.AppImage` or `.deb` | Same as above |

These builds aren't signed yet. The first time: on Windows click
**More info → Run anyway**; on a Mac right-click Where → **Open**.

## Build it yourself

The setup script works out which computer it's on — Windows, Mac or Linux,
Intel/AMD or ARM — installs anything missing, builds the right app for it,
and opens Where.

| Your computer | Run | You get |
|---|---|---|
| **Windows** | double-click **`start-where.bat`** | `Where.exe`, plus Desktop and Start menu shortcuts |
| **Mac** | double-click **`start-where.command`** | `Where.app` in `~/Applications` (Launchpad, Spotlight) |
| **Linux** | `bash start-where.sh` in a terminal | `Where`, added to your applications menu |

What gets installed if it's missing:

- **Windows:** Git, Visual Studio C++ Build Tools, Rust, Flutter. Turn on
  **Developer Mode** when asked.
- **Mac:** Xcode from the App Store (the script opens it for you — install
  and open it once), CocoaPods, Rust, Flutter.
- **Linux:** clang, cmake, ninja, pkg-config and GTK 3 via `apt`, `dnf`,
  `pacman` or `zypper` (you'll be asked for your password), Rust, Flutter.

The first run downloads several GB of tools and can take 20–40 minutes.
Later runs take about a minute.

| Option | What it does |
|---|---|
| *(none)* | Set up if needed, build, open Where |
| `update` | Get the latest code from GitHub first |
| `cli` | Build and open the command-line version |

e.g. `start-where.bat update` or `bash start-where.sh update`.

If something goes wrong, the script shows the last lines of its log:
`%LOCALAPPDATA%\where-tools\setup-log.txt` on Windows,
`~/.where-tools/setup-log.txt` on Mac and Linux.

### Publishing a release

1. Write the notes in `docs/releases/vX.Y.Z.md` (first line `# Title` becomes
   the release name). Without a file, the CHANGELOG section is used.
2. Push to `main`, then push a tag: `git tag -a vX.Y.Z -m "…"` and
   `git push origin vX.Y.Z`.
3. GitHub builds the Windows, Mac and Linux downloads on its own machines and
   publishes the Release. See
   [`.github/workflows/release.yml`](.github/workflows/release.yml).

## Save links from your browser

1. In Chrome, Edge or Brave, open the extensions page (`chrome://extensions`)
   and turn on **Developer mode**.
2. Click **Load unpacked** and pick the `browser-extension` folder. After
   running `start-where.bat` there's also a copy next to `Where.exe`.
3. Pin the Where button, click it on any page, then **Connect** and
   **Allow** in Where.

The extension only talks to Where on your own computer. Details in
[browser-extension/README.md](browser-extension/README.md).

## Keyboard shortcuts

| Keys | Action |
|---|---|
| `Ctrl K` | Quick actions and search |
| `Ctrl 1` – `Ctrl 6` | Home, Projects, Tasks, Notes, Links, Files |
| `Alt+Shift+W` (browser) | Save the current page to Where |
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
| `browser-extension/` | Save pages from Chrome, Edge or Brave |
| `scripts/` | Packaging for Mac and Linux (used by `start-where.sh` and releases) |
| `installer/` | Windows installer (Inno Setup) |
| `docs/` | [Product spec](docs/SPEC.md) and [architecture decisions](docs/adr/) |

## Status

**v0.4.0 — alpha.** Windows, Mac and Linux, with installers. See the [changelog](CHANGELOG.md).

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
asking. Details: [PRIVACY.md](PRIVACY.md).

## Development

```sh
cargo test --all
cargo clippy --all-targets -- -D warnings
cargo fmt --all
```

See [CONTRIBUTING.md](CONTRIBUTING.md). Work is planned in Notion
(Where → Roadmap & Tasks); link the Notion task in each pull request.

## Project documents

| | |
|---|---|
| [CHANGELOG.md](CHANGELOG.md) | What changed in each version |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to help, and keeping private files out of the repo |
| [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) | How we treat each other |
| [SECURITY.md](SECURITY.md) | Reporting vulnerabilities privately |
| [PRIVACY.md](PRIVACY.md) | What Where stores and what it never does |
| [SUPPORT.md](SUPPORT.md) | Getting help and common fixes |
| [docs/](docs/) | Product spec and architecture decisions |

## License

No license has been chosen yet, so all rights are reserved by the author.
You're welcome to read the code and suggest changes; please ask before
reusing it elsewhere.
