# Repository Guidelines

## Project Overview

WeSafeChat — macOS menu-bar app (AppKit, no SwiftUI) that auto-hides WeChat on focus loss or user inactivity. macOS 13+, no code signing.

## Architecture

Single delegate class, timer-driven:

```
main.swift → AppDelegate (NSApplicationDelegate)
src/AppDelegate.swift — UI, menu, timer logic
src/Migration.swift    — UserDefaults schema migration
src/ExtInt.swift       — Int.then() utility
```

**State**: focusLossEnabled, focusLossDelaySeconds, idleDetectionEnabled, idleDelaySeconds, isHidden (persisted to UserDefaults, keys match var names).

**Focus-loss detection**: NSWorkspace notifications + `frontmostApplication?.bundleIdentifier == "com.tencent.xinWeChat"`. Independent toggle, uses `focusLossDelaySeconds` (default 3s).

**Idle detection**: `CGEventSource.secondsSinceLastEventType(.hidSystemState, ...)` polling 15 event types every 0.5s. No Accessibility permissions needed. Independent toggle, uses `idleDelaySeconds` (default 5s).

**Hide**: `NSRunningApplication.hide()` on all WeChat instances, 0.5s debounce on isHidden flag.

**Status icon**: `eye` when either toggle is on, `eye.slash` when both are off. `updateStatusIcon()` centralized helper.

## Data Migration

UserDefaults schema upgrades are driven by `schemaVersion` (integer). See [docs/migration.md](docs/migration.md) for the detailed guide.

At a glance:
- `Migration.run()` is called first in `applicationDidFinishLaunching`
- Each migration step is a private static method (`migrateToV1`, `migrateToV2`, ...)
- `schemaVersion` only increments when data shape changes, not on every release
- New file: `src/Migration.swift` — struct with static methods

## Development Commands

```bash
bash install.sh --install --run     # build + install + launch
bash install.sh --output ./build    # build to custom dir
swiftlint lint                      # check code style
swiftlint lint --fix                # auto-fix safe violations
bash scripts/check-release.sh 0.3.4  # pre-tag validation
bash scripts/tag-release.sh 0.3.4     # validate + tag + push
```

## install.sh Flags

`--install|--no-install` `--run|--no-run` `--link` `--output <dir>` — absent = interactive prompt.

## Build System

`swiftc main.swift src/*.swift -framework Cocoa -framework ServiceManagement`. No Xcode, no SPM.

Icon pipeline: resources/logo.png → sips (10 sizes) → iconutil → .icns → bundle Resources.

## CI/CD

Tag push `v*` → GitHub Actions on `macos-latest` → build .app.zip → create Release → update Cask in `CaffreySun/homebrew-tap` (needs `TAP_TOKEN` secret).

## Distribution

```bash
brew tap caffreysun/tap
brew install --cask wesafechat
```

Cask `postflight` strips `com.apple.quarantine` xattr.

## Conventions

- Timers: always `[weak self]`, invalidate before creating new, add to `RunLoop.current` .common mode
- Menu item titles in Chinese
- Menu structure: each feature toggle is immediately followed by its delay submenu
- SMAppService for login item
- Info.plist: LSUIElement=true (no dock icon)
- Info.plist: keep CFBundleShortVersionString in sync with git tag. CFBundleVersion is auto-generated as yyMMddHHmm at build time.
- CHANGELOG.md: newest version at the top, both in content sections and bottom reference links
- Data migration: `schemaVersion` integer in UserDefaults, `Migration` struct with per-version `private static func`, see docs/migration.md
