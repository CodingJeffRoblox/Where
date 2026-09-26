# Contributing to Where

Thanks for helping. Where is small and early, so the process is light.

## Before you start

- Read the [product spec](docs/SPEC.md) — especially the principles (§5)
  and the product boundaries (§40).
- Look at open [issues](https://github.com/ItsJeffTheDev/Where/issues)
  or the roadmap. For anything bigger than a small fix, open an issue first
  so we can agree on the approach.

## Set up

Run the setup script for your computer — `start-where.bat` (Windows),
`start-where.command` (Mac) or `bash start-where.sh` (Linux). It installs
the tools and builds everything. Details in the [README](README.md#build-it-yourself).

If you add or edit a script on Windows, keep it executable for Mac and Linux:
`git update-index --chmod=+x <file>`.

## Make a change

1. Branch from `main`: `feat/<short-name>` or `fix/<short-name>`.
2. Keep these green before you push:
   ```sh
   cargo fmt --all
   cargo clippy --all-targets -- -D warnings
   cargo test --all
   ```
   For the app: `flutter analyze` and `flutter test` in `apps/where_flutter`.
3. Write commit messages in the imperative: *"Add link filter"*, not
   *"added…"*.
4. Update [`CHANGELOG.md`](CHANGELOG.md) under **Unreleased** for anything
   a user would notice.
5. Open a pull request and fill in the template.

Significant technical choices get a short ADR in [`docs/adr/`](docs/adr/).

## Keep private things out of the repo

Only source code and docs belong here. **Before every push**, check what
you're about to commit:

```sh
git status
git diff --cached --stat
```

Never commit databases (`*.db`), exports, logs, build output, `.env` files,
keys or passwords. [`.gitignore`](.gitignore) blocks the common ones — if
something slips through, remove it from the repo (it stays on your disk):

```sh
git rm -r --cached .
git add .
git commit -m "Stop tracking files that aren't source code"
```

Use GitHub's private email for commits so your real address isn't public:
GitHub → Settings → Emails → *Keep my email addresses private*, then
`git config --global user.email "<id>+<username>@users.noreply.github.com"`.

## Product rules that reviews will check

Where must never delete or change the user's files, send messages, upload
data by default, or run commands without confirmation (spec §40). New
permissions — a folder, a browser, an integration — must be explicit and
visible in Settings.

## Code of conduct

Be kind and constructive. See [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).
