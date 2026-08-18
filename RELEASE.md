# Release Guide

This project ships as a signed and notarized macOS app distributed by GitHub
Releases and Homebrew Cask.

## Prerequisites

- Xcode command line tools
- Apple Developer ID Application certificate
- A stored notary profile:

```bash
xcrun notarytool store-credentials typeback-notary --apple-id tulingjiaoyu@gmail.com
```

If you are building from mainland China, set a proxy before dependency fetches:

```bash
export HTTP_PROXY=http://127.0.0.1:7890
export HTTPS_PROXY=http://127.0.0.1:7890
export ALL_PROXY=socks5://127.0.0.1:7890
```

## Version

Keep the release version in `VERSION`. The packaging script reads from that file.

## Local Verification

```bash
swift build
swift build -c release
```

For a quick unsigned/notarization-skipped packaging check:

```bash
./package.sh --skip-notarize --no-fancy
```

`--no-fancy` is kept for compatibility. The current DMG builder does not use
Finder or AppleScript, which avoids Finder metadata/provenance issues on newer
macOS releases.

## Full Release

One command does everything — package, notarize, create the GitHub release,
and sync the Homebrew cask to the tap:

```bash
./release.sh
```

Prerequisites: bump `VERSION` first, and have a clean checkout of the
homebrew-tap repo at `../homebrew-tap` (override with `TAP_DIR`).

`release.sh` runs `package.sh --no-fancy` internally, then:

1. `gh release create "v$(cat VERSION)" dist/TypeBack.dmg`
2. Renders `Casks/typeback.rb` (the canonical cask definition lives in this
   repo — never edit the tap copy by hand) with the new version and SHA-256
3. Commits and pushes the cask update to homebrew-tap

`package.sh`/`release.sh` accept these environment overrides:

- `BUNDLE_ID`
- `SIGN_IDENTITY`
- `NOTARY_PROFILE`
- `TAP_DIR`

## Homebrew Cask

Homebrew is the only distribution channel. Users install with:

```bash
brew tap leftrk/tap
brew install --cask typeback
```

The cask file in homebrew-tap is generated from `Casks/typeback.rb` in this
repo by `release.sh`. To change the cask body (zap list, caveats, etc.),
edit the template here and it will be synced on the next release.
