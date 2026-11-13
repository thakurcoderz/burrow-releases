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

**macOS in one line** (Apple Silicon). Downloads the newest `.dmg`, checks its
SHA-256, installs Burrow.app into /Applications and links the `burrow` command.
No "Apple could not verify" prompt, because files downloaded by curl aren't
quarantined:

```sh
curl -fsSL https://raw.githubusercontent.com/thakurcoderz/burrow-releases/main/install.sh | sh
burrow setup
```

A specific version: `curl -fsSL …/install.sh | BURROW_VERSION=0.3.2 sh`. Running it
again updates Burrow in place.

Install instructions: https://burrow-website-steel.vercel.app/docs/install/

The builds are made by this repository's workflow from Burrow's source at the
release tag.
