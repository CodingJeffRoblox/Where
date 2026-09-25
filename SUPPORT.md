# Getting help

## Setup problems

1. Run the setup script again — `start-where.bat` (Windows),
   `start-where.command` (Mac) or `bash start-where.sh` (Linux). It fixes most
   problems itself.
2. If it still fails, look at the last lines of the log:
   `%LOCALAPPDATA%\where-tools\setup-log.txt` (Windows) or
   `~/.where-tools/setup-log.txt` (Mac, Linux).
3. Open an [issue](https://github.com/CodingJeffRoblox/Where/issues/new/choose)
   with those lines. **Check them for private information first** (names,
   paths, emails) and replace anything you don't want to share.

## Common fixes

| Problem | Fix |
|---|---|
| `LNK1104: cannot open file ... Where.exe` | Close Where, then run the script again. |
| `No target "where_flutter"` | Delete `apps\where_flutter\build`, then run the script again. |
| Developer Mode message | Settings → For developers → Developer Mode **On**. |
| Mac: "Where can't be opened" | Right-click Where → **Open** (only the first time). |
| Mac: "Xcode is needed" | Install Xcode from the App Store, open it once, run the script again. |
| Mac: `start-where.command` won't run | In Terminal: `chmod +x start-where.command start-where.sh` |
| Linux: `Permission denied` | Run `bash start-where.sh` (or `chmod +x start-where.sh`). |
| Linux: missing `libgtk-3` | Install GTK 3 (`sudo apt install libgtk-3-0`, or your distro's equivalent). |
| Browser says "Where isn't running" | Open Where first. Only one copy can run the browser connection. |
| Browser extension missing | Settings → Browser in Where shows the three install steps. |

## Ideas and questions

Open an issue with the **Feature request** template, or start a
discussion.

## Security issues

Don't post them publicly — see [SECURITY.md](SECURITY.md).
