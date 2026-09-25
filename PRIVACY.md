# Privacy

Where is built to keep your information on your computer.

## What Where stores

Everything lives in one database file on your computer, plus a small
`settings.json` next to it:

| Computer | Folder |
|---|---|
| Windows | `%APPDATA%\CrownCore Studios\Where\` |
| Mac | `~/Library/Application Support/com.crowncorestudios.where/` |
| Linux | `~/.local/share/com.crowncorestudios.where/` |

Settings → Privacy in Where shows the exact path.

It contains:

- Projects, tasks, notes and links you create.
- For folders **you choose** to index: each file's name, location, size,
  dates, type and a fingerprint (hash). **Not** the file's contents.
- The browsers you've allowed to connect (a random access key per browser).

## What Where does not do

- No account, no cloud, no sync.
- No telemetry, analytics or crash reporting.
- No AI services.
- No activity tracking or screen capture.
- It never changes, moves, deletes or uploads your files.
- It doesn't download website icons, so your saved links aren't revealed to
  anyone.

## Browser extension

The extension only talks to Where on your own computer
(`127.0.0.1:47771`). It reads the current page's title and address **only
when you click it** (or right-click → Save to Where). It doesn't read page
contents or browsing history. Each browser must be approved once in Where,
and can be disconnected in Settings → Browser.

## Removing your data

- Delete a single item with the trash icon on its page.
- Stop indexing a folder by removing it from Settings (coming soon) or by
  deleting the database.
- Delete everything: close Where and delete the `where.db` file above.

## Exports

Settings → Export writes a copy to a folder you pick. It's your file — Where
doesn't send it anywhere.

Questions: open an issue, or see [SECURITY.md](SECURITY.md) for anything
sensitive.
