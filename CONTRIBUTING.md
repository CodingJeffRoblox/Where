# Contributing

1. Pick a task from Notion (Where → Roadmap) and set it to **In progress**.
2. Branch: `feat/<short-name>` or `fix/<short-name>`.
3. Keep `cargo fmt`, `cargo clippy -D warnings` and `cargo test` green.
4. Open a PR; paste the Notion task link in the description. Once merged,
   mark the task **Done** and add the PR link to it.
5. Significant technical choices get an ADR in `docs/adr/` and a row in the
   Notion Decisions log.

Product boundaries (spec §40) are non-negotiable: never delete user files,
never send messages, never upload data by default, always confirm
destructive actions.
