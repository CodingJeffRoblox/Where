#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Build the Where desktop app for the computer this runs on (macOS or Linux).
# Used by start-where.sh and by the GitHub release workflow.
#
#   scripts/package.sh              build for this computer
#   scripts/package.sh --universal  macOS: engine for both Apple Silicon and Intel
#   scripts/package.sh --archive    also write a download to dist/
#
# Needs: Rust (cargo), Flutter, and the platform build tools
# (Xcode on macOS; clang, cmake, ninja, pkg-config, GTK 3 on Linux).
# On success prints:  WHERE_APP=<path to the app>
# ---------------------------------------------------------------------------
set -euo pipefail

UNIVERSAL=0
ARCHIVE=0
for arg in "$@"; do
  case "$arg" in
    --universal) UNIVERSAL=1 ;;
    --archive) ARCHIVE=1 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="$ROOT/apps/where_flutter"
VERSION="$(sed -n 's/^version = "\(.*\)"/\1/p' "$ROOT/Cargo.toml" | head -1)"
ORG="com.crowncorestudios"
BUNDLE_ID="$ORG.where"

case "$(uname -s)" in
  Darwin) OS=macos ;;
  Linux) OS=linux ;;
  *) echo "package.sh builds for macOS and Linux. On Windows, run start-where.bat." >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) ARCH=x64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *) echo "Unsupported processor: $(uname -m)" >&2; exit 1 ;;
esac

say() { printf '    %s\n' "$*"; }

# --------------------------------------------------------------- engine ----
say ".. Building the search engine ($OS, $ARCH)"
if [[ "$OS" == macos && "$UNIVERSAL" == 1 ]]; then
  rustup target add aarch64-apple-darwin x86_64-apple-darwin >/dev/null
  cargo build --release --manifest-path "$ROOT/Cargo.toml" -p where_ffi --target aarch64-apple-darwin
  cargo build --release --manifest-path "$ROOT/Cargo.toml" -p where_ffi --target x86_64-apple-darwin
  mkdir -p "$ROOT/target/universal"
  ENGINE="$ROOT/target/universal/libwhere_ffi.dylib"
  lipo -create -output "$ENGINE" \
    "$ROOT/target/aarch64-apple-darwin/release/libwhere_ffi.dylib" \
    "$ROOT/target/x86_64-apple-darwin/release/libwhere_ffi.dylib"
else
  cargo build --release --manifest-path "$ROOT/Cargo.toml" -p where_ffi -p where_cli
  if [[ "$OS" == macos ]]; then ENGINE="$ROOT/target/release/libwhere_ffi.dylib"
  else ENGINE="$ROOT/target/release/libwhere_ffi.so"; fi
fi
[[ -f "$ENGINE" ]] || { echo "Engine not found at $ENGINE" >&2; exit 1; }

# ------------------------------------------------- platform project files ----
# The macOS/Linux project folders are generated here (they aren't committed),
# then renamed to "Where" with our own bundle id.
cd "$APP"
if [[ ! -d "$OS/runner" && ! -d "$OS/Runner" ]]; then
  say ".. Creating $OS project files"
  flutter create --platforms="$OS" --project-name where_flutter --org "$ORG" . >/dev/null
fi

# Portable in-place edit (GNU and BSD sed differ).
edit() { local expr="$1" file="$2"; sed -e "$expr" "$file" > "$file.tmp" && mv "$file.tmp" "$file"; }

if [[ "$OS" == linux ]]; then
  edit 's/^set(BINARY_NAME ".*")/set(BINARY_NAME "Where")/' linux/CMakeLists.txt
  edit "s/^set(APPLICATION_ID \".*\")/set(APPLICATION_ID \"$BUNDLE_ID\")/" linux/CMakeLists.txt
  # Window title
  while IFS= read -r f; do edit 's/"where_flutter"/"Where"/g' "$f"; done \
    < <(grep -rl '"where_flutter"' linux --include='*.cc' || true)
else
  CFG="macos/Runner/Configs/AppInfo.xcconfig"
  edit 's/^PRODUCT_NAME = .*/PRODUCT_NAME = Where/' "$CFG"
  edit "s/^PRODUCT_BUNDLE_IDENTIFIER = .*/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID/" "$CFG"
  edit 's/^PRODUCT_COPYRIGHT = .*/PRODUCT_COPYRIGHT = Copyright © 2026 CrownCore Studios. All rights reserved./' "$CFG"
  # Where is distributed outside the App Store: turn off the sandbox so it can
  # re-index the folders you chose after a restart, and allow the local
  # browser connection (127.0.0.1 only).
  for ent in macos/Runner/DebugProfile.entitlements macos/Runner/Release.entitlements; do
    [[ -f "$ent" ]] || continue
    cat > "$ent" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>com.apple.security.app-sandbox</key>
	<false/>
	<key>com.apple.security.network.server</key>
	<true/>
	<key>com.apple.security.network.client</key>
	<true/>
	<key>com.apple.security.files.user-selected.read-only</key>
	<true/>
</dict>
</plist>
PLIST
  done
  # App icon from the master artwork.
  ICONSET="macos/Runner/Assets.xcassets/AppIcon.appiconset"
  if [[ -d "$ICONSET" ]] && command -v sips >/dev/null; then
    for n in 16 32 64 128 256 512 1024; do
      sips -z "$n" "$n" "$ROOT/assets/icon/where-1024.png" --out "$ICONSET/app_icon_$n.png" >/dev/null
    done
  fi
fi

# ------------------------------------------------------------------ build ----
say ".. Getting app packages"
flutter pub get >/dev/null

build_app() { flutter build "$OS" --release; }
say ".. Compiling the app"
if ! build_app; then
  # A cache from before the app was renamed can break the build: clean, retry.
  say "!! First attempt failed - cleaning and trying once more"
  rm -rf "build/$OS"
  build_app
fi

# ----------------------------------------------------------------- bundle ----
if [[ "$OS" == linux ]]; then
  OUT="$APP/build/linux/$ARCH/release/bundle"
  [[ -x "$OUT/Where" ]] || { echo "Build finished but $OUT/Where is missing" >&2; exit 1; }
  mkdir -p "$OUT/lib"
  cp "$ENGINE" "$OUT/lib/"
  rm -rf "$OUT/browser-extension"
  cp -R "$ROOT/browser-extension" "$OUT/browser-extension"
  cp "$ROOT/assets/icon/where-512.png" "$OUT/where.png"
  APP_PATH="$OUT/Where"
else
  OUT="$APP/build/macos/Build/Products/Release/Where.app"
  [[ -d "$OUT" ]] || { echo "Build finished but $OUT is missing" >&2; exit 1; }
  mkdir -p "$OUT/Contents/Frameworks" "$OUT/Contents/Resources"
  cp "$ENGINE" "$OUT/Contents/Frameworks/"
  rm -rf "$OUT/Contents/Resources/browser-extension"
  cp -R "$ROOT/browser-extension" "$OUT/Contents/Resources/browser-extension"
  # Re-sign after adding files. "-" = ad-hoc: runs on this Mac; downloads
  # still need right-click > Open until the app is notarized.
  codesign --force --deep --sign - "$OUT" >/dev/null 2>&1 || say "!! Could not sign the app (it may still run)"
  APP_PATH="$OUT"
fi

# --------------------------------------------------------- linux packages ----
DESKTOP_ID="com.crowncorestudios.where"

desktop_entry() {  # $1 = Exec line
  cat <<DESKTOP
[Desktop Entry]
Type=Application
Name=Where
GenericName=Search
Comment=Find what you're looking for
Exec=$1
Icon=$DESKTOP_ID
Terminal=false
Categories=Utility;Office;
Keywords=search;find;files;notes;tasks;projects;links;
StartupWMClass=Where
DESKTOP
}

# .deb for Debian, Ubuntu, Mint, Pop!_OS...  Installs to /opt/where.
build_deb() {
  local debarch; debarch=$([[ "$ARCH" == x64 ]] && echo amd64 || echo arm64)
  local work; work="$(mktemp -d)"
  local pkg="$work/where_${VERSION}_${debarch}"
  mkdir -p "$pkg/DEBIAN" "$pkg/opt/where" "$pkg/usr/bin" \
    "$pkg/usr/share/applications" "$pkg/usr/share/icons/hicolor/512x512/apps"
  cp -R "$OUT/." "$pkg/opt/where/"
  rm -f "$pkg/opt/where/install.sh"
  ln -s /opt/where/Where "$pkg/usr/bin/where"
  desktop_entry "/opt/where/Where" > "$pkg/usr/share/applications/$DESKTOP_ID.desktop"
  cp "$ROOT/assets/icon/where-512.png" "$pkg/usr/share/icons/hicolor/512x512/apps/$DESKTOP_ID.png"
  cat > "$pkg/DEBIAN/control" <<CONTROL
Package: where
Version: $VERSION
Architecture: $debarch
Maintainer: CodingJeffRoblox <CodingJeffRoblox@users.noreply.github.com>
Depends: libgtk-3-0 | libgtk-3-0t64
Section: utils
Priority: optional
Homepage: https://github.com/CodingJeffRoblox/Where
Description: Find what you're looking for
 Where connects your files, notes, tasks, projects and saved links in one
 private, offline search. Nothing leaves your computer.
CONTROL
  find "$pkg" -type d -exec chmod 755 {} +
  dpkg-deb --root-owner-group --build "$pkg" "$ROOT/dist/Where-$VERSION-linux-$ARCH.deb" >/dev/null
  rm -rf "$work"
  say "OK dist/Where-$VERSION-linux-$ARCH.deb"
}

# AppImage: one file that runs on most Linux distributions.
build_appimage() {
  local tool="${APPIMAGETOOL:-appimagetool}"
  local work; work="$(mktemp -d)"
  local appdir="$work/Where.AppDir"
  mkdir -p "$appdir/usr/lib/where"
  cp -R "$OUT/." "$appdir/usr/lib/where/"
  rm -f "$appdir/usr/lib/where/install.sh"
  cat > "$appdir/AppRun" <<'APPRUN'
#!/bin/sh
HERE="$(dirname "$(readlink -f "$0")")"
exec "$HERE/usr/lib/where/Where" "$@"
APPRUN
  chmod +x "$appdir/AppRun"
  desktop_entry "Where" > "$appdir/$DESKTOP_ID.desktop"
  cp "$ROOT/assets/icon/where-512.png" "$appdir/$DESKTOP_ID.png"
  cp "$ROOT/assets/icon/where-512.png" "$appdir/.DirIcon"
  local image="$ROOT/dist/Where-$VERSION-linux-$ARCH.AppImage"
  # appimagetool reads the CPU type from ARCH, spelled its own way.
  local tool_arch; tool_arch=$([[ "$ARCH" == x64 ]] && echo x86_64 || echo aarch64)
  env ARCH="$tool_arch" "$tool" --no-appstream "$appdir" "$image" >/dev/null
  rm -rf "$work"
  say "OK dist/Where-$VERSION-linux-$ARCH.AppImage"
}

# ---------------------------------------------------------------- archive ----
if [[ "$ARCHIVE" == 1 ]]; then
  mkdir -p "$ROOT/dist"
  if [[ "$OS" == linux ]]; then
    NAME="Where-$VERSION-linux-$ARCH"
    STAGE="$(mktemp -d)"
    cp -R "$OUT" "$STAGE/Where"
    cp "$ROOT/scripts/linux-install.sh" "$STAGE/Where/install.sh"
    chmod +x "$STAGE/Where/install.sh" "$STAGE/Where/Where"
    tar -C "$STAGE" -czf "$ROOT/dist/$NAME.tar.gz" Where
    rm -rf "$STAGE"
    say "OK dist/$NAME.tar.gz"
    if command -v dpkg-deb >/dev/null; then build_deb; fi
    if [[ -n "${APPIMAGETOOL:-}" ]] || command -v appimagetool >/dev/null; then build_appimage; fi
  else
    SUFFIX=$([[ "$UNIVERSAL" == 1 ]] && echo universal || echo "$ARCH")
    NAME="Where-$VERSION-macos-$SUFFIX"
    rm -f "$ROOT/dist/$NAME.zip" "$ROOT/dist/$NAME.dmg"
    ditto -c -k --keepParent "$OUT" "$ROOT/dist/$NAME.zip"
    STAGE="$(mktemp -d)"
    cp -R "$OUT" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    hdiutil create -volname "Where" -srcfolder "$STAGE" -ov -format UDZO "$ROOT/dist/$NAME.dmg" >/dev/null
    rm -rf "$STAGE"
    say "OK dist/$NAME.zip and dist/$NAME.dmg"
  fi
fi

echo "WHERE_APP=$APP_PATH"
