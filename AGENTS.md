# Repository Guidelines

## Project Overview

WeSafeChat is a macOS menu-bar application that auto-hides WeChat when focus is lost or the user is idle. Built with AppKit (no SwiftUI, no storyboard), targeting macOS 13+.

## Architecture & Data Flow

```
main.swift (entry, 4 lines)
  └─ src/AppDelegate.swift (sole controller, ~265 lines)
       ├─ NSStatusItem → menu bar icon + NSMenu
       ├─ NSWorkspace notifications → focus detection
       ├─ Timer (closeTimer) → hides WeChat after focus loss + delay
       ├─ Timer (idleCheckTimer) → hides WeChat on inactivity (CGEventSource polling)
       ├─ UserDefaults → persists isSafing, delaySeconds, idleDetectionEnabled
       ├─ SMAppService → login item registration
       └─ NSRunningApplication.hide() → hides WeChat windows
src/ExtInt.swift (utility, 4 lines)
```

**State machine**:
- `idle` → toggleSafeMode → `safing`
- `safing` + WeChat loses focus → closeTimer (delaySeconds) → hideWeChat()
- `safing` + WeChat has focus + idle ≥ delaySeconds → idleCheckTimer → hideWeChat()
- `safing` → toggleSafeMode → `idle`

**Threading**: all Timer callbacks and UI on main thread. One `DispatchQueue.main.asyncAfter` for hide debounce (0.5s).

## Key Directories

| Directory | Purpose |
|---|---|
| `src/` | Swift source (AppDelegate, utility extensions) |
| `scripts/` | Release build script |
| `.github/workflows/` | CI release pipeline |
| `build/` | Build output (gitignored) |

## Development Commands

```bash
# Manual build & run
bash install.sh --install --run

# Build only, output to custom dir
bash install.sh --no-install --output ./build

# Release packaging (from CI or locally)
bash scripts/release.sh 0.3.3

# Publish a release (triggers CI)
git tag v0.3.3 && git push --tags
```

**Compilation**: `swiftc main.swift src/*.swift -framework Cocoa -framework ServiceManagement`

No Xcode project, no Package.swift, no SPM dependencies.

## Code Conventions

- **Language**: Swift 5.x, pure AppKit (no SwiftUI)
- **Architecture**: Single delegate class (`AppDelegate: NSObject, NSApplicationDelegate`), no MV* separation
- **State**: Mutable instance vars (`isSafing`, `isHidden`, `idleDetectionEnabled`), persisted via `UserDefaults.standard` with keys matching var names
- **Timers**: Always create via `Timer.scheduledTimer`, add to `RunLoop.current` with `.common` mode. Invalidate before creating new ones (`cancelCloseTimer()` before `startCloseTimer()`)
- **Weak self**: All timer closures use `[weak self]` guard
- **Default values**: `delaySeconds` defaults to 5 via `Int.then` extension
- **Naming**: Chinese menu item titles (`启动`, `停止`, `无操作隐藏`, `开机自启`, `安全延迟`, `退出`)

## Important Files

| File | Role |
|---|---|
| `main.swift` | Entry point: NSApplication + AppDelegate + run |
| `src/AppDelegate.swift` | All app logic: menu bar, monitoring, timers, persistence |
| `src/ExtInt.swift` | `Int.then()` utility extension |
| `install.sh` | Build script: compile, bundle .app, icon generation, install/launch/symlink |
| `scripts/release.sh` | Release packaging: wraps install.sh, zips .app, prints SHA256 |
| `Info.plist` | Bundle config: `LSUIElement=true`, min macOS 13.0 |
| `.github/workflows/release.yml` | CI triggered on `v*` tags, builds + releases + updates Cask |
| `logo.png` | App icon source (1024x1024, required at project root) |

## install.sh Flags

| Flag | Effect |
|---|---|
| `--install` | Auto-install to `/Applications`, no prompt |
| `--no-install` | Skip install, no prompt |
| `--run` | Auto-launch after install, no prompt |
| `--no-run` | Skip launch, no prompt |
| `--link` | Create symlink at `/Applications/WeSafeChat.app` |
| `--output <dir>` | Output directory (default: `build`) |

## CI/CD

- **Trigger**: `git push --tags` with `v*` tag
- **Runner**: `macos-latest`
- **Steps**:
  1. Build & zip via `scripts/release.sh`
  2. Create GitHub Release with `.app.zip` asset
  3. Clone `CaffreySun/homebrew-tap`, update `Casks/wesafechat.rb` (version + SHA256), push
- **Secrets**: `TAP_TOKEN` — GitHub PAT with `Contents: write` on homebrew-tap repo

## Distribution

**Homebrew Cask** (recommended):
```bash
brew tap caffreysun/tap
brew install --cask wesafechat
```

Cask includes `postflight` to remove `com.apple.quarantine` xattr (no code signing). Manual build via `install.sh` also supported.

## Key Patterns

- **No permissions needed**: Idle detection uses `CGEventSource.secondsSinceLastEventType(.hidSystemState, ...)` — query-only API, no Accessibility entitlement
- **Focus detection**: `NSWorkspace.didActivateApplicationNotification` / `didDeactivateApplicationNotification` + `frontmostApplication?.bundleIdentifier`
- **Idle detection**: Polls 15 `CGEventType` values via `CGEventSource`, takes minimum idle time. Check interval: 0.5s
- **Hide mechanism**: `NSRunningApplication.hide()` on all WeChat instances
- **Persistence**: `UserDefaults` for `isSafing`, `delaySeconds`, `idleDetectionEnabled`. `SMAppService.mainApp` for login item
- **Debounce**: After hide, `isHidden` flag reset after 0.5s via `DispatchQueue.main.asyncAfter`
