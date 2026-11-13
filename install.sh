#!/bin/sh
# Install or update Burrow from the Terminal, on macOS or Linux:
#
#   curl -fsSL https://raw.githubusercontent.com/thakurcoderz/burrow-releases/main/install.sh | sh
#
#   macOS (Apple Silicon)   Burrow.app into /Applications, `burrow` linked into
#                           /usr/local/bin. Files downloaded with curl aren't
#                           quarantined, so there's no "Apple could not verify
#                           Burrow" prompt (Burrow isn't notarized yet).
#   Ubuntu / Debian x86-64  the .deb (package burrow-desktop) via apt, with its
#                           dependencies.
#   Other Linux x86-64      just burrowd and burrow into /usr/local/bin (the
#                           desktop app needs a Debian-based system).
#
# Every download is checked against the release's SHA256SUMS first.
# BURROW_VERSION=0.3.2 picks a version (default: the newest).
# BURROW_DRY_RUN=1 resolves, downloads and verifies, then stops.
set -eu

REPO="thakurcoderz/burrow-releases"
BIN_DIR="/usr/local/bin"

say() { printf '%s\n' "$*"; }
fail() { printf 'burrow install: %s\n' "$*" >&2; exit 1; }
as_root() { if [ "$(id -u)" = 0 ]; then "$@"; else sudo "$@"; fi; }

command -v curl >/dev/null || fail "curl is required"
dry="${BURROW_DRY_RUN:-}"

# Platform.
os=$(uname -s)
arch=$(uname -m)
case "$os/$arch" in
  Darwin/arm64) kind=mac ;;
  Darwin/*) fail "Burrow for macOS needs an Apple Silicon Mac (M1 or newer); Intel Macs aren't supported yet." ;;
  Linux/x86_64 | Linux/amd64)
    if command -v apt-get >/dev/null 2>&1 && command -v dpkg >/dev/null 2>&1; then kind=deb; else kind=tar; fi ;;
  Linux/*) fail "Burrow for Linux is built for x86-64; $arch isn't supported yet." ;;
  *) fail "Burrow runs on macOS (Apple Silicon) and Linux (x86-64), not $os." ;;
esac
[ -z "${BURROW_KIND:-}" ] || kind="$BURROW_KIND" # testing: mac | deb | tar

# Version.
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
case "$kind" in
  mac) file="Burrow_${version}_aarch64.dmg" ;;
  deb) file="Burrow_${version}_amd64.deb" ;;
  tar) file="burrow-${version}-linux-x86_64.tar.gz" ;;
  *) fail "unknown install kind: $kind" ;;
esac
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

# Download and verify.
say "Downloading Burrow $version ($file)…"
curl -fL --progress-bar -o "$tmp/$file" "$base/$file" || fail "download failed: $base/$file"
curl -fsSL -o "$tmp/SHA256SUMS" "$base/SHA256SUMS" || fail "couldn't download SHA256SUMS"
want=$(awk -v f="$file" '$2 == f || $2 == "*" f { print $1 }' "$tmp/SHA256SUMS" | head -n 1)
[ -n "$want" ] || fail "$file isn't listed in SHA256SUMS"
if command -v sha256sum >/dev/null 2>&1; then
  got=$(sha256sum "$tmp/$file" | awk '{ print $1 }')
else
  got=$(shasum -a 256 "$tmp/$file" | awk '{ print $1 }')
fi
[ "$got" = "$want" ] || fail "checksum mismatch for $file (expected $want, got $got); not installing"
say "Checksum OK."

if [ -n "$dry" ]; then
  say "Dry run ($kind): verified $file; nothing installed."
  exit 0
fi

link_cli() {
  # $1: path of the burrow binary to link as $BIN_DIR/burrow
  if [ -d "$BIN_DIR" ] && [ -w "$BIN_DIR" ]; then
    ln -sf "$1" "$BIN_DIR/burrow"
  else
    as_root mkdir -p "$BIN_DIR"
    as_root ln -sf "$1" "$BIN_DIR/burrow"
  fi
}

case "$kind" in
  mac)
    mkdir -p "$mnt"
    hdiutil attach "$tmp/$file" -nobrowse -readonly -quiet -mountpoint "$mnt" || fail "couldn't open the .dmg"
    [ -d "$mnt/Burrow.app" ] || fail "Burrow.app not found in the .dmg"
    if pgrep -f "/Burrow.app/Contents/MacOS/" >/dev/null 2>&1; then
      say "Quitting the running Burrow app…"
      osascript -e 'quit app "Burrow"' >/dev/null 2>&1 || true
      sleep 2
    fi
    target="/Applications/Burrow.app"
    say "Installing Burrow.app into /Applications…"
    if [ -w /Applications ] && { [ ! -e "$target" ] || [ -w "$target" ]; }; then
      rm -rf "$target"
      ditto "$mnt/Burrow.app" "$target"
    else
      as_root rm -rf "$target"
      as_root ditto "$mnt/Burrow.app" "$target"
    fi
    xattr -dr com.apple.quarantine "$target" 2>/dev/null || true
    say "Linking $BIN_DIR/burrow…"
    link_cli "$target/Contents/MacOS/burrow"
    ;;
  deb)
    say "Installing the package (apt asks for your password)…"
    # apt needs a path it can read as its sandbox user.
    chmod 755 "$tmp" && chmod 644 "$tmp/$file"
    as_root apt-get install -y "$tmp/$file" || fail "apt couldn't install $file"
    ;;
  tar)
    say "Installing burrowd and burrow into $BIN_DIR (no apt here, so no desktop app)…"
    tar -xzf "$tmp/$file" -C "$tmp"
    for b in burrowd burrow; do
      [ -f "$tmp/$b" ] || fail "$b missing from $file"
      as_root install -m 0755 "$tmp/$b" "$BIN_DIR/$b"
    done
    ;;
esac

say ""
say "Burrow $version is installed."
restarted=""
if [ "$kind" = mac ]; then
  if launchctl print "gui/$(id -u)/dev.burrow.burrowd" >/dev/null 2>&1; then
    launchctl kickstart -k "gui/$(id -u)/dev.burrow.burrowd" >/dev/null 2>&1 && restarted=1
  fi
elif command -v systemctl >/dev/null 2>&1 && systemctl --user cat burrowd >/dev/null 2>&1; then
  systemctl --user restart burrowd >/dev/null 2>&1 && restarted=1
fi
if [ -n "$restarted" ]; then
  say "Restarted burrowd on the new version."
  [ "$kind" = tar ] || say "Reopen the Burrow app if it's running."
else
  say "Next, once: run   burrow setup   (sets up .test DNS, HTTPS and the background service)."
  [ "$kind" = tar ] || say "Then open Burrow from your apps."
fi
