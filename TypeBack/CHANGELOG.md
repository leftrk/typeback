# Changelog

All notable changes to TypeBack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.7] - 2026-06-06

### Fixed
- Restore floating indicator initialization that was accidentally removed during
  the macOS 26 menu bar simplification work.

## [1.1.6] - 2026-06-06

### Changed
- Remove leftover Sparkle/appcast release documentation and scripts so the
  project has one update path: Homebrew.

## [1.1.5] - 2026-06-06

### Fixed
- Restore TypeBack as a pure menu bar app: add `LSUIElement`, use a traditional
  AppKit entry point, and remove the macOS 26 floating fallback.
- Remove Sparkle and keep Homebrew as the only update channel, reducing launch
  complexity for macOS 26 menu bar status item registration.

## [1.1.4] - 2026-06-06

### Fixed
- Add a macOS 26 floating `TB` fallback control at the top-right of the screen.
  It opens the same TypeBack menu even when Control Center or historical Ice /
  Hidden Bar caches swallow the native `NSStatusItem`.

## [1.1.3] - 2026-06-06

### Fixed
- Use a visible `TB` text menu bar item instead of relying on an SF Symbol as the
  only visible content, preventing macOS 26 from showing an invisible but active
  status item.

## [1.1.2] - 2026-06-06

### Fixed
- Set a stable menu bar status item autosave name to avoid duplicate TypeBack
  entries in macOS 26 Control Center/Menu Bar settings.
- Expand the macOS 26 cache cleanup script to remove additional Control Center
  preference caches before relaunching TypeBack.

## [1.1.1] - 2026-06-06

### Fixed
- **macOS 26 (Tahoe) menu bar icon visibility issue**:
  - Root cause: `LSMinimumSystemVersion=14.0` caused macOS 26 to place status items off-screen
  - Solution: Removed `LSMinimumSystemVersion` from Info.plist (minimum version enforced by Package.swift)
  - Removed `LSUIElement` key (activation policy set programmatically in `applicationWillFinishLaunching`)
- Moved `setActivationPolicy(.accessory)` to `applicationWillFinishLaunching` for proper timing

### Important for macOS 26 Users
**If you previously installed TypeBack v1.1.0 or earlier, your menu bar icon may remain hidden due to system cache.**

Fix options:
1. **Recommended**: Run the cleanup script after installing v1.1.1:
   ```bash
   curl -sL https://raw.githubusercontent.com/leftrk/typeback/main/cleanup-macos26-cache.sh | bash
   brew reinstall --cask typeback
   ```
2. **Alternative**: Restart your Mac after updating to v1.1.1

For **new users** on macOS 26, the menu bar icon will display correctly on first install.

### Added
- EventTap failure auto-recovery mechanism (watches for `kCGEventTapDisabledByTimeout` and `kCGEventTapDisabledByUserInput`)
- Real-time accessibility permission monitoring with user notification
- Input method API error handling and fallback
- Structured logging with automatic rotation (size limit: 1MB, max files: 5)
- Multi-display support for floating indicator
- GitHub Issues feedback menu item
- `cleanup-macos26-cache.sh` script for users upgrading from v1.1.0
- CHANGELOG.md and SemVer versioning convention

## [1.1.0] - 2026-06-05

### Added
- Sparkle auto-update support
- DMG packaging and notarization workflow

## [1.0.3] - 2026-05-26

### Fixed
- Shortcut recording improvements
- Candidate box detection refinements

## [1.0.2] - 2026-05-26

### Fixed
- Minor bug fixes

## [1.0.1] - 2026-04-22

### Fixed
- Initial release refinements

## [1.0.0] - 2026-04-22

### Added
- Initial release
- Floating indicator showing input method status
- Customizable shortcut to switch back to English
- Auto-switch after Chinese typing pause timeout
- Caps Lock guard option
