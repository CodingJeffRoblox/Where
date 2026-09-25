# where_flutter

The Where desktop app (Flutter). Talks to the Rust core through `dart:ffi`
(`crates/where_ffi`), passing JSON strings across the boundary.

> Status: alpha. Builds for Windows, macOS and Linux.

## Features

- **Home** — search everything as you type, results grouped by kind with
  matches highlighted; quick actions, live counts and recent items.
- **Projects / Tasks / Notes / Files** — sidebar sections with cards, task
  checkboxes and filters, note previews, indexed folders.
- **Detail pages** — edit titles inline, notes autosave, task status, move
  to a project, open or reveal files, and everything connected.
- **Ctrl K** command palette — create, jump, index, export, switch theme.
- **Settings** — theme, indexed folders, privacy panel, export.
- Subtle motion throughout: fades, staggered lists, hover lift, animated
  checkboxes and counters. Folder indexing runs in the background.

## Run it

Use the setup script in the repo root — `start-where.bat` (Windows),
`start-where.command` (Mac) or `bash start-where.sh` (Linux). It installs
everything, builds, bundles the engine into the app and opens it. Mac and
Linux packaging lives in [`scripts/package.sh`](../../scripts/package.sh).

### Manually (Windows / macOS / Linux)

```sh
# 1. Build the native core from the repo root
cargo build -p where_ffi --release

# 2. Generate platform folders once (not committed yet)
cd apps/where_flutter
flutter create --platforms=windows,macos,linux --project-name where_flutter .

# 3. Point the app at the library and run
#    Windows: target\release\where_ffi.dll
#    macOS:   target/release/libwhere_ffi.dylib
#    Linux:   target/release/libwhere_ffi.so
WHERE_FFI_LIB=../../target/release/libwhere_ffi.so flutter run -d linux
```

Bundling the library into the app package (instead of `WHERE_FFI_LIB`) is
a Phase 1 task.

## What's here

- `lib/main.dart` — startup, theme, friendly error if the engine is missing.
- `lib/src/where_core.dart` — typed wrapper over the C ABI.
- `lib/src/state.dart` — app state, settings, background indexing.
- `lib/src/shell.dart` — sidebar, section transitions, keyboard shortcuts.
- `lib/src/command_palette.dart` — Ctrl K.
- `lib/src/pages/` — home, projects, tasks, notes, files, settings, detail.
- `lib/src/widgets.dart`, `theme.dart`, `models.dart` — shared UI pieces.
