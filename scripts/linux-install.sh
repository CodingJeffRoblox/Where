#!/usr/bin/env bash
# Adds Where to your applications menu. Run from the unpacked Where folder:
#   ./install.sh            add to the menu (uses this folder)
#   ./install.sh --remove   remove it again
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APPS="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
ICONS="${XDG_DATA_HOME:-$HOME/.local/share}/icons/hicolor/512x512/apps"
DESKTOP="$APPS/com.crowncorestudios.where.desktop"

if [[ "${1:-}" == "--remove" ]]; then
  rm -f "$DESKTOP" "$ICONS/com.crowncorestudios.where.png"
  echo "Removed Where from the applications menu. (This folder was not touched.)"
  exit 0
fi

[[ -x "$HERE/Where" ]] || { echo "Run this from the Where folder (Where not found in $HERE)." >&2; exit 1; }
mkdir -p "$APPS" "$ICONS"
cp "$HERE/where.png" "$ICONS/com.crowncorestudios.where.png"
cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Where
GenericName=Search
Comment=Find what you're looking for
Exec="$HERE/Where"
Icon=com.crowncorestudios.where
Terminal=false
Categories=Utility;Office;
Keywords=search;find;files;notes;tasks;projects;links;
StartupWMClass=Where
EOF
chmod +x "$DESKTOP"
command -v update-desktop-database >/dev/null && update-desktop-database "$APPS" >/dev/null 2>&1 || true
echo "Added Where to your applications menu."
echo "Browser extension folder: $HERE/browser-extension"
