# Repository Guidelines

## Project Overview

WeSafeChat — macOS menu-bar app (AppKit, no SwiftUI) that auto-hides WeChat on focus loss or user inactivity. macOS 13+, no code signing.

## Architecture

Side effects pushed to boundary, core is pure input→output. See [docs/architecture.md](docs/architecture.md) for design rationale and side effect classification.

```
main.swift → AppDelegate (NSApplicationDelegate)
src/AppDelegate.swift      — thin shell: UI, system glue, action executor
src/logic/Core.swift       — pure state machine: Event → [Action]  (100% coverage)
src/logic/Migration.swift  — UserDefaults schema migration         (100% coverage)
```

**AppDelegate**: NSStatusBar/NSMenu, translates NSWorkspace/NSTimer to `core.handle(Event)`, executes returned `[Action]`.

**Core**: Pure logic. No Cocoa imports. Receives `Event`, returns `[Action]`. All state lives here. Separately testable without AppKit.

**Test**: `tests/TestCore.swift` asserts `core.handle(event) == [Action]`. No spy, no mock, no framework. `tests/TestMigration.swift` tests schema upgrades with `UserDefaults(suiteName:)`.

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
bash install.sh --test              # compile & run tests
bash scripts/test.sh                # run tests directly
swiftlint lint                      # check code style
swiftlint lint --fix                # auto-fix safe violations
bash scripts/check-release.sh 0.3.4  # pre-tag validation
bash scripts/tag-release.sh 0.3.4     # validate + tag + push
```

## install.sh Flags

`--install|--no-install` `--run|--no-run` `--link` `--output <dir>` `--test` — absent = interactive prompt.

## Build System

`swiftc main.swift src/*.swift src/logic/*.swift -framework Cocoa -framework ServiceManagement`. No Xcode, no SPM.

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
- Tests: no XCTest/SPM. Compile test files + src files with `swiftc`, run executable → exit 0/1
- Test pattern: `assertEqual(core.handle(event), [Action])` — equality comparison on Action lists
- Coverage: `src/logic/` must be 100% line coverage. Enforced by `scripts/test.sh`
- New pure logic → `src/logic/` + 100% tests required. New system glue → `src/` no coverage requirement
