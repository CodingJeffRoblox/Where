# Getting help

## Setup problems

1. Run `start-where.bat` again — it fixes most problems itself.
2. If it still fails, open
   `%LOCALAPPDATA%\where-tools\setup-log.txt` and look at the last lines.
3. Open an [issue](https://github.com/CodingJeffRoblox/Where/issues/new/choose)
   with those lines. **Check them for private information first** (names,
   paths, emails) and replace anything you don't want to share.

## Common fixes

| Problem | Fix |
|---|---|
| `LNK1104: cannot open file ... Where.exe` | Close Where, then run the script again. |
| `No target "where_flutter"` | Delete `apps\where_flutter\build`, then run the script again. |
| Developer Mode message | Settings → For developers → Developer Mode **On**. |
| Browser says "Where isn't running" | Open Where first. Only one copy can run the browser connection. |
| Browser extension missing | Settings → Browser in Where shows the three install steps. |

## Ideas and questions

Open an issue with the **Feature request** template, or start a
discussion.

## Security issues

Don't post them publicly — see [SECURITY.md](SECURITY.md).
