# 3. Flutter ↔ Rust through a small JSON-over-C-ABI boundary

Date: 2026-09-24 · Status: Accepted (revisit at end of Phase 1)

## Context
The Flutter app needs the Rust core. Options: flutter_rust_bridge (codegen),
a hand-written C ABI, or a local server.

## Decision
Start with a hand-written C ABI in `crates/where_ffi`: a handful of
functions that take UTF-8 strings and return `{"ok": …}` / `{"error": …}`
JSON strings. Dart wraps them in `lib/src/where_core.dart`.

## Consequences
- + No codegen toolchain; the API is tiny and easy to test from Rust.
- − JSON encode/decode per call; calls are synchronous on the UI isolate.
  Fine for search on small indexes; move indexing to a background isolate
  or adopt flutter_rust_bridge if profiling says so.
- The Flutter CI job is non-blocking until its first green run.
