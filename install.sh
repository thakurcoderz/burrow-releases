#!/bin/sh
# Install Burrow on macOS (Apple Silicon) from the Terminal:
#
#   curl -fsSL https://raw.githubusercontent.com/thakurcoderz/burrow-releases/main/install.sh | sh
#
# Downloads the newest release's .dmg (or BURROW_VERSION=0.3.2), checks its
# SHA-256 against the release's SHA256SUMS, installs Burrow.app into
# /Applications (replacing an older copy) and links the `burrow` command into
# /usr/local/bin. Files downloaded with curl aren't quarantined, so macOS
# doesn't show "Apple could not verify Burrow" (Burrow isn't notarized yet).
#
# BURROW_DRY_RUN=1 resolves, downloads and verifies, then stops (any OS).
set -eu

REPO="thakurcoderz/burrow-releases"
APP_DIR="/Applications"
BIN_DIR="/usr/local/bin"

say() { printf '%s\n' "$*"; }
fail() { printf 'burrow install: %s\n' "$*" >&2; exit 1; }

dry="${BURROW_DRY_RUN:-}"
if [ -z "$dry" ]; then
  [ "$(uname -s)" = Darwin ] || fail "this installer is for macOS. On Linux, download the .deb: https://github.com/$REPO/releases/latest"
  [ "$(uname -m)" = arm64 ] || fail "Burrow for macOS needs an Apple Silicon Mac (M1 or newer); Intel Macs aren't supported yet."
fi
command -v curl >/dev/null || fail "curl is required"

# Which version.
version="${BURROW_VERSION:-}"
version="${version#v}"
if [ -z "$version" ]; then
  tag=$(curl -fsSL "https://api.github.com/repos/$REPO/releases/latest" \
    | sed -n 's/.*"tag_name": *"\([^"]*\)".*/\1/p' | head -n 1)
  [ -n "$tag" ] || fail "couldn't find the latest release (GitHub API unreachable or rate-limited); try BURROW_VERSION=0.3.2"
  version="${tag#v}"
fi
case "$version" in
  *[!0-9.]* | "") fail "bad version: $version" ;;
esac
dmg="Burrow_${version}_aarch64.dmg"
base="https://github.com/$REPO/releases/download/v$version"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/burrow-install.XXXXXX")
mnt="$tmp/mnt"
cleanup() {
  if [ -d "$mnt" ] && command -v hdiutil >/dev/null 2>&1; then
    hdiutil detach "$mnt" -quiet 2>/dev/null || true
  fi
  rm -rf "$tmp"
}
trap cleanup EXIT INT TERM

say "Downloading Burrow $version…"
curl -fL --progress-bar -o "$tmp/$dmg" "$base/$dmg" || fail "download failed: $base/$dmg"
curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" || fail "couldn't download SHA256SUMS"

want=$(awk -v f="$dmg" '$2 == f || $2 == "*" f { print $1 }' "$tmp/SHA256SUMS" | head -n 1)
[ -n "$want" ] || fail "$dmg isn't listed in SHA256SUMS"
if command -v shasum >/dev/null 2>&1; then
  got=$(shasum -a 256 "$tmp/$dmg" | awk '{ print $1 }')
else
  got=$(sha256sum "$tmp/$dmg" | awk '{ print $1 }')
fi
[ "$got" = "$want" ] || fail "checksum mismatch for $dmg (expected $want, got $got); not installing"
say "Checksum OK."

if [ -n "$dry" ]; then
  say "Dry run: would install Burrow.app $version into $APP_DIR and link $BIN_DIR/burrow."
  exit 0
fi

# Root only where needed (an admin can usually write /Applications).
as_root() {
  if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi
}

mkdir -p "$mnt"
hdiutil attach "$tmp/$dmg" -nobrowse -readonly -quiet -mountpoint "$mnt" || fail "couldn't open the .dmg"
[ -d "$mnt/Burrow.app" ] || fail "Burrow.app not found in the .dmg"

if pgrep -x burrow-desktop >/dev/null 2>&1 || pgrep -f "/Burrow.app/Contents/MacOS/" >/dev/null 2>&1; then
  say "Quitting the running Burrow app…"
  osascript -e 'quit app "Burrow"' >/dev/null 2>&1 || true
  sleep 2
fi

say "Installing Burrow.app into $APP_DIR…"
target="$APP_DIR/Burrow.app"
if [ -w "$APP_DIR" ] && { [ ! -e "$target" ] || [ -w "$target" ]; }; then
  rm -rf "$target"
  ditto "$mnt/Burrow.app" "$target"
else
  as_root rm -rf "$target"
  as_root ditto "$mnt/Burrow.app" "$target"
fi
xattr -dr com.apple.quarantine "$target" 2>/dev/null || true

say "Linking $BIN_DIR/burrow…"
if [ -d "$BIN_DIR" ] && [ -w "$BIN_DIR" ]; then
  ln -sf "$target/Contents/MacOS/burrow" "$BIN_DIR/burrow"
else
  as_root mkdir -p "$BIN_DIR"
  as_root ln -sf "$target/Contents/MacOS/burrow" "$BIN_DIR/burrow"
fi

say ""
say "Burrow $version is installed."
if command -v launchctl >/dev/null 2>&1 && launchctl print "gui/$(id -u)/dev.burrow.burrowd" >/dev/null 2>&1; then
  launchctl kickstart -k "gui/$(id -u)/dev.burrow.burrowd" >/dev/null 2>&1 || true
  say "Restarted burrowd. Open Burrow from Applications."
else
  say "Next, once: run   burrow setup   (sets up .test DNS, HTTPS and the background service),"
  say "then open Burrow from Applications."
fi
