#!/usr/bin/env bash
# ==========================================================================
#  Where - one-step setup and launch for macOS and Linux
#
#    ./start-where.sh           set up (if needed), build, and open Where
#    ./start-where.sh update    get the latest code from GitHub first
#    ./start-where.sh cli       build and open the command-line version
#
#  Works out which computer it's on (macOS or Linux, Intel/AMD or ARM) and
#  installs anything missing: build tools, Rust and Flutter.
#  On Windows, use start-where.bat instead.
#  Detailed output goes to ~/.where-tools/setup-log.txt
# ==========================================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TOOLS="$HOME/.where-tools"
FLUTTER_HOME="$TOOLS/flutter"
LOG="$TOOLS/setup-log.txt"
MODE="${1:-}"
mkdir -p "$TOOLS"
export PATH="$HOME/.cargo/bin:$FLUTTER_HOME/bin:$PATH"
echo "===== $(date) - start-where.sh $MODE =====" >> "$LOG"

# ---- look ------------------------------------------------------------------
if [[ -t 1 ]]; then
  C_OK=$'\e[92m'; C_WARN=$'\e[93m'; C_ERR=$'\e[91m'; C_DIM=$'\e[90m'; C_HEAD=$'\e[1;97m'; C_ACC=$'\e[96m'; C_END=$'\e[0m'
else
  C_OK=; C_WARN=; C_ERR=; C_DIM=; C_HEAD=; C_ACC=; C_END=
fi
step() { printf '\n  %s[%s/5] %s%s\n' "$C_HEAD" "$1" "$2" "$C_END"; }
ok()   { printf '    %sOK%s  %s\n' "$C_OK" "$C_END" "$1"; }
work() { printf '    %s..%s  %s\n' "$C_ACC" "$C_END" "$1"; }
warn() { printf '    %s!!%s  %s\n' "$C_WARN" "$C_END" "$1"; }
err()  { printf '    %sXX  %s%s\n' "$C_ERR" "$1" "$C_END"; }
note() { printf '        %s%s%s\n' "$C_DIM" "$1" "$C_END"; }
have() { command -v "$1" >/dev/null 2>&1; }

fail() {
  echo
  printf '  %sSetup stopped.%s Fix the problem above, then run ./start-where.sh again.\n' "$C_ERR" "$C_END"
  printf '  %sLast lines of the log (%s):%s\n' "$C_DIM" "$LOG" "$C_END"
  tail -n 25 "$LOG" | sed 's/^/    /'
  exit 1
}

# ---- which computer is this? ------------------------------------------------
case "$(uname -s)" in
  Darwin) OS=macos; OS_NAME="macOS $(sw_vers -productVersion 2>/dev/null)" ;;
  Linux)
    OS=linux
    OS_NAME="Linux"
    if [[ -r /etc/os-release ]]; then
      # shellcheck disable=SC1091
      . /etc/os-release
      OS_NAME="${PRETTY_NAME:-Linux}"
    fi
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "This is Windows - running start-where.bat instead..."
    exec cmd.exe //c "$(cygpath -w "$ROOT/start-where.bat")" "$MODE"
    ;;
  *) echo "Where doesn't support $(uname -s) yet." >&2; exit 1 ;;
esac
case "$(uname -m)" in
  x86_64|amd64) ARCH=x64; CHIP="Intel/AMD (x64)" ;;
  arm64|aarch64) ARCH=arm64; CHIP="ARM (arm64)" ;;
  *) echo "Unsupported processor: $(uname -m)" >&2; exit 1 ;;
esac
if [[ "$OS" == macos && "$ARCH" == arm64 ]]; then CHIP="Apple Silicon"; fi

clear 2>/dev/null || true
echo
printf '  %sW H E R E%s   %sfind what you'"'"'re looking for%s\n' "$C_HEAD" "$C_END" "$C_DIM" "$C_END"
printf '  %s---------------------------------------------------%s\n' "$C_DIM" "$C_END"
printf '  %sThis computer: %s, %s%s\n' "$C_DIM" "$OS_NAME" "$CHIP" "$C_END"

[[ -f "$ROOT/Cargo.toml" ]] || { err "Run this from the Where folder (Cargo.toml not found)."; exit 1; }

# ---- installers ---------------------------------------------------------------
# The log file belongs to you, so it's written without sudo on purpose.
# shellcheck disable=SC2024
linux_install() {
  # $@ = packages for this distro's package manager
  sudo -v || return 1   # ask for the password up front, visibly
  if have apt-get; then sudo apt-get update -y >>"$LOG" 2>&1; sudo apt-get install -y "$@" >>"$LOG" 2>&1
  elif have dnf; then sudo dnf install -y "$@" >>"$LOG" 2>&1
  elif have pacman; then sudo pacman -S --needed --noconfirm "$@" >>"$LOG" 2>&1
  elif have zypper; then sudo zypper --non-interactive install "$@" >>"$LOG" 2>&1
  else return 1; fi
}

ensure_linux_tools() {
  local missing=0
  for t in git curl unzip clang cmake ninja pkg-config; do have "$t" || missing=1; done
  if have pkg-config && ! pkg-config --exists gtk+-3.0; then missing=1; fi
  if [[ $missing == 0 ]]; then ok "Build tools"; return 0; fi
  work "Installing build tools (you may be asked for your password)..."
  if have apt-get; then
    linux_install git curl unzip xz-utils zip clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
  elif have dnf; then
    linux_install git curl unzip xz zip clang cmake ninja-build pkgconf-pkg-config gtk3-devel xz-devel libstdc++-devel
  elif have pacman; then
    linux_install git curl unzip xz zip clang cmake ninja pkgconf gtk3
  elif have zypper; then
    linux_install git curl unzip xz zip clang cmake ninja pkg-config gtk3-devel xz-devel
  else
    err "Couldn't find apt, dnf, pacman or zypper to install build tools."
    note "Install: git curl unzip clang cmake ninja pkg-config and GTK 3 development files."
    return 1
  fi || { err "Installing build tools failed."; return 1; }
  ok "Build tools installed"
}

ensure_mac_tools() {
  if ! xcode-select -p >/dev/null 2>&1; then
    work "Installing Apple's command line tools - a window will open, click Install..."
    xcode-select --install >>"$LOG" 2>&1 || true
    err "Finish the command line tools install, then run ./start-where.sh again."
    return 1
  fi
  if ! xcodebuild -version >/dev/null 2>&1; then
    err "Xcode is needed to build Mac apps."
    note "Install Xcode from the App Store (free), open it once to finish setup,"
    note "then run: sudo xcode-select -s /Applications/Xcode.app"
    open "macappstore://apps.apple.com/app/xcode/id497799835" 2>/dev/null || true
    return 1
  fi
  ok "Xcode $(xcodebuild -version | head -1 | awk '{print $2}')"
  if ! have pod; then
    if have brew; then
      work "Installing CocoaPods (used by some app plugins)..."
      brew install cocoapods >>"$LOG" 2>&1 || warn "CocoaPods didn't install - the build may still work."
    else
      warn "CocoaPods not found. If the app build fails, install Homebrew (brew.sh), then: brew install cocoapods"
    fi
  fi
}

ensure_rust() {
  if have cargo; then ok "Rust"; return 0; fi
  work "Installing Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal >>"$LOG" 2>&1 \
    || { err "Rust install failed."; return 1; }
  export PATH="$HOME/.cargo/bin:$PATH"
  ok "Rust installed"
}

ensure_flutter() {
  if ! have flutter; then
    if [[ ! -x "$FLUTTER_HOME/bin/flutter" ]]; then
      work "Downloading Flutter..."
      git clone --depth 1 -b stable https://github.com/flutter/flutter.git "$FLUTTER_HOME" >>"$LOG" 2>&1 \
        || { err "Could not download Flutter."; return 1; }
    fi
    add_to_shell_path "$FLUTTER_HOME/bin"
  fi
  if [[ ! -f "$TOOLS/flutter-ready" ]]; then
    work "Preparing Flutter for first use - a few minutes..."
    flutter config --no-analytics >>"$LOG" 2>&1
    flutter config "--enable-$OS-desktop" >>"$LOG" 2>&1
  fi
  flutter --version >>"$LOG" 2>&1 || { err "Flutter failed to start. Run 'flutter doctor' to see why."; return 1; }
  touch "$TOOLS/flutter-ready"
  ok "Flutter"
}

add_to_shell_path() {
  local dir="$1" rc
  for rc in "$HOME/.zshrc" "$HOME/.bashrc"; do
    [[ -f "$rc" || "$rc" == "$HOME/.zshrc" && "$OS" == macos ]] || continue
    grep -qs "$dir" "$rc" || printf '\n# Added by Where setup\nexport PATH="%s:$PATH"\n' "$dir" >> "$rc"
  done
}

close_running_app() {
  if pgrep -x Where >/dev/null 2>&1; then
    work "Closing Where so it can be updated..."
    if [[ "$OS" == macos ]]; then osascript -e 'quit app "Where"' >/dev/null 2>&1; sleep 2; fi
    pkill -x Where >/dev/null 2>&1 || true
    sleep 1
  fi
}

update_code() {
  if [[ ! -d "$ROOT/.git" ]]; then warn "This folder isn't a git clone, so it can't update itself. Skipping."; return 0; fi
  work "Getting the latest code..."
  if git -C "$ROOT" pull --ff-only >>"$LOG" 2>&1; then ok "Code is up to date"
  else warn "Couldn't update automatically - you may have local changes. Continuing."; fi
}

make_shortcut() {
  local app="$1"
  if [[ "$OS" == linux ]]; then
    local bundle; bundle="$(dirname "$app")"
    cp "$ROOT/scripts/linux-install.sh" "$bundle/install.sh"
    bash "$bundle/install.sh" >>"$LOG" 2>&1 && ok "Added Where to your applications menu"
  else
    # Keep a copy in ~/Applications so it shows up in Launchpad and Spotlight.
    mkdir -p "$HOME/Applications"
    rm -rf "$HOME/Applications/Where.app"
    cp -R "$app" "$HOME/Applications/Where.app" && ok "Added Where to ~/Applications (Launchpad, Spotlight)"
  fi
}

# ---- 1. tools -----------------------------------------------------------------
step 1 "Checking what's installed"
if [[ "$OS" == linux ]]; then ensure_linux_tools || fail; else ensure_mac_tools || fail; fi
[[ "$MODE" == update ]] && update_code
ensure_rust || fail

if [[ "$MODE" == cli ]]; then
  work "Building the command-line version..."
  cargo build --release --manifest-path "$ROOT/Cargo.toml" -p where_cli >>"$LOG" 2>&1 || fail
  export PATH="$ROOT/target/release:$PATH"
  echo
  printf '  %sWhere command line is ready.%s Try:\n' "$C_HEAD" "$C_END"
  printf '    %swhere-cli demo --db /tmp/where-demo.db%s\n' "$C_ACC" "$C_END"
  printf '    %swhere-cli index ~/Documents%s\n' "$C_ACC" "$C_END"
  printf '    %swhere-cli search report%s\n\n' "$C_ACC" "$C_END"
  exec "${SHELL:-bash}"
fi

ensure_flutter || fail

# ---- 2. system ----------------------------------------------------------------
step 2 "Checking this computer"
ok "$OS_NAME on $CHIP"
close_running_app

# ---- 3 & 4. build ---------------------------------------------------------------
step 3 "Building the search engine and the app"
work "Compiling - the first build takes a few minutes, later ones less than a minute..."
OUTPUT="$(bash "$ROOT/scripts/package.sh" 2>>"$LOG" | tee -a "$LOG")" || { err "The build didn't finish."; fail; }
APP_PATH="$(printf '%s\n' "$OUTPUT" | sed -n 's/^WHERE_APP=//p' | tail -1)"
[[ -n "$APP_PATH" && -e "$APP_PATH" ]] || { err "The build finished but the app wasn't found."; fail; }
ok "Where is built"

step 4 "Adding Where to your computer"
make_shortcut "$APP_PATH"

# ---- 5. launch --------------------------------------------------------------
step 5 "Starting Where"
if [[ "$OS" == macos ]]; then open "$APP_PATH"; else (nohup "$APP_PATH" >/dev/null 2>&1 &); fi
ok "Where is open"
echo
printf '  %sNext time, open Where from your %s.%s\n' "$C_DIM" "$([[ $OS == macos ]] && echo "Applications folder or Spotlight" || echo "applications menu")" "$C_END"
printf '  %sTo save pages from your browser, see Where - Settings - Browser.%s\n\n' "$C_DIM" "$C_END"
