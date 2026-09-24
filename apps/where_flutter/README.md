# where_flutter

The Where desktop app (Flutter). Talks to the Rust core through `dart:ffi`
(`crates/where_ffi`), passing JSON strings across the boundary.

> Status: first shell. It has not yet been compiled in CI — see the
> "Flutter app" checklist in the Notion roadmap.

## Run it (Windows / macOS / Linux)

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

- `lib/src/where_core.dart` — typed wrapper over the C ABI.
- `lib/main.dart` — search-first home screen (spec §30): search box, results
  grouped by kind, arrow-key navigation, Enter to open, quick-create for
  projects/tasks/notes, "Index a folder", light/dark themes.
