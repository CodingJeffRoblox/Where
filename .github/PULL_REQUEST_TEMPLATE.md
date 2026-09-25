## What does this change?

<!-- One or two sentences. Link the issue or Notion task. -->

## How was it tested?

- [ ] `cargo fmt`, `cargo clippy -D warnings`, `cargo test` pass
- [ ] App built and tried on Windows (if the app changed)
- [ ] Screenshots attached (if the UI changed)

## Checklist

- [ ] No private data in the diff (databases, logs, exports, paths, emails, keys)
- [ ] `CHANGELOG.md` updated under **Unreleased** (if users will notice)
- [ ] Follows the product boundaries: never changes user files, uploads data
      or runs commands without asking (spec §40)
