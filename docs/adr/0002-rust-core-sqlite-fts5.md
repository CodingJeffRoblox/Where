# 2. Rust core with SQLite + FTS5 as the local source of truth

Date: 2026-09-24 · Status: Accepted (validate in Phase 0 prototype)

## Context
Spec §20–§24: local-first, offline, cross-platform, fast keyword search, no
mandatory AI.

## Decision
- All domain logic lives in Rust crates (`where_core`, `where_storage`,
  `where_search`, `where_indexer`). UIs are thin.
- One SQLite file per user profile. `rusqlite` with the `bundled` feature so
  every platform ships the same SQLite version with FTS5.
- FTS5 external-content table kept in sync by triggers; BM25 weights
  title 10 / body 1 / searchable properties 3.
- Only canonical relation direction is stored (`Project contains Task`);
  inverses ("part of") are derived at read time.
- Ids are UUIDv7 (time-ordered, globally unique — ready for sync later).
- Migrations are append-only, tracked with `PRAGMA user_version`.

## Consequences
Search needs no network or AI. Semantic search (spec §24) can later be added
as another ranked source without changing storage.
