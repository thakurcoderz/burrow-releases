# Burrow releases

Downloads for [Burrow](https://burrow-website-steel.vercel.app), the Laravel
development environment. Get the newest version from
[Releases](https://github.com/thakurcoderz/burrow-releases/releases/latest):

- `Burrow_<version>_amd64.deb`: Linux (Ubuntu 22.04+), the desktop app with `burrowd` and `burrow`
- `Burrow_<version>_aarch64.dmg`: macOS on Apple Silicon (not notarized yet: on first launch run
  `xattr -dr com.apple.quarantine /Applications/Burrow.app`, or System Settings →
  Privacy & Security → **Open Anyway**)
- `burrow-<version>-<platform>.tar.gz`: just `burrowd` and `burrow`
- `SHA256SUMS`: checksums of every file

**Install or update in one line** (macOS on Apple Silicon, or Linux x86-64):

```sh
curl -fsSL https://raw.githubusercontent.com/thakurcoderz/burrow-releases/main/install.sh | sh
burrow setup   # once, the first time
```

The script picks the right download, checks its SHA-256 against `SHA256SUMS`,
then installs it:

- **macOS:** Burrow.app goes into /Applications and `burrow` into `/usr/local/bin`.
  There's no "Apple could not verify" prompt, because curl downloads aren't
  quarantined.
- **Ubuntu/Debian:** the `.deb` (package `burrow-desktop`) via apt.
- **Other Linux:** `burrowd` and `burrow` into `/usr/local/bin`.

Running it again updates in place and restarts `burrowd`. For a specific
version, pipe it to `BURROW_VERSION=0.3.2 sh` instead of `sh`.

Install instructions: https://burrow-website-steel.vercel.app/docs/install/

The builds are made by this repository's workflow from Burrow's source at the
release tag.
