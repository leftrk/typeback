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

```bash
./package.sh --no-fancy
gh release create "v$(cat VERSION)" dist/TypeBack.dmg
```

`package.sh` accepts these environment overrides:

- `BUNDLE_ID`
- `SIGN_IDENTITY`
- `NOTARY_PROFILE`

## Homebrew Cask

Update your tap with the release version and SHA-256 printed by `package.sh`.

```ruby
cask "typeback" do
  version "1.1.5"
  sha256 "53ef5d00053960f1b9deb52cf8131e115ebbe41a58189c05f2c34ccf22f3f390"

  url "https://github.com/leftrk/typeback/releases/download/v#{version}/TypeBack.dmg"
  name "TypeBack"
  desc "macOS input method state indicator and automatic switch-back tool"
  homepage "https://github.com/leftrk/typeback"

  livecheck do
    url :url
    strategy :github_latest
  end

  depends_on macos: ">= :sonoma"

  app "TypeBack.app"

  zap trash: [
    "~/Library/Preferences/com.huaguan.typeback.plist",
    "~/Library/Application Support/com.huaguan.typeback",
    "~/Library/Caches/com.huaguan.typeback",
  ]

  caveats <<~EOS
    TypeBack needs Accessibility permission to monitor keyboard events:
      System Settings -> Privacy & Security -> Accessibility -> add TypeBack
  EOS
end
```

Users can then install it with:

```bash
brew tap leftrk/tap
brew install --cask typeback
```
