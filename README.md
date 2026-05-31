# Chrono

A lightweight macOS menu bar timer built for the macOS 26 design language — liquid glass, prominent floating elements, and a dynamically sizing status bar pill.

**Current version:** 1.0.1  
**Bundle ID:** `com.bekher.Chrono`

## Preview

<p align="center">
  <img src="https://tojp4f5baeta7girwrpqvogul40oddhk.lambda-url.eu-central-1.on.aws/img/in-next-app/chrono-01.jpg?w=3840&q=75&f=webp" alt="Chrono app icon" width="180" />
  &nbsp;&nbsp;
  <img src="https://tojp4f5baeta7girwrpqvogul40oddhk.lambda-url.eu-central-1.on.aws/img/in-next-app/chrono-02.jpg?w=3840&q=75&f=webp" alt="Chrono menu bar pill and floating timer panel" width="640" />
</p>

<p align="center"><em>App icon · Menu bar timer with liquid glass floating panel</em></p>

---

## Overview

Chrono lives in the menu bar as a compact time-tracking pill. Click it to open a borderless floating panel with Start, Stop, and Reset controls. Tap the info icon to expand an about pane with a smooth downward reveal.

The app deliberately avoids standard `NSPopover` chrome. A custom `NSPanel` bridge (`MenuBarManager`) coordinates with SwiftUI layout so the window grows downward without jumping — the top edge stays pinned while content animates inside.

### Features

- **Liquid glass UI** — `NSVisualEffectView` (`.hudWindow`) with 26pt continuous corner radius
- **Smart expansion** — Info pane reveals via a SwiftUI mask animation synced to a single AppKit frame update
- **Stable menu bar pill** — Tabular monospaced digits; the status item width tracks elapsed time without jitter
- **Keyboard shortcuts** — Start/stop and reset from anywhere (see in-app info pane)
- **Inactivity detection** — Optional auto-stop when idle

---

## Requirements

- macOS 14+
- Xcode 15+ / Swift 5.9+

---

## Quick start

### Open in Xcode

```bash
open Chrono.xcodeproj
```

### Clean build (Debug)

From the project root:

```bash
rm -rf .DerivedData
xcodebuild -scheme Chrono \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .DerivedData \
  build
open .DerivedData/Build/Products/Debug/Chrono.app
```

### Release build

```bash
xcodebuild -scheme Chrono \
  -configuration Release \
  -destination 'platform=macOS' \
  build
```

---

## Release DMG

The release pipeline builds icons, compiles a Release `.app`, stages a styled disk image, and writes the final artifact to `dist/`.

```bash
bash scripts/build-dmg.sh
```

**Output:** `dist/Chrono-1.0.1.dmg`

The script runs six steps: preflight → `.icns` → Release `.app` → DMG staging → Finder cosmetics → compressed read-only DMG.

> **Note:** Release DMGs from this script are not code-signed or notarized. Recipients may need **Right-click → Open** on first launch.

To bump the version for the next release, update `VERSION` and `BUILD_NUMBER` in `scripts/build-dmg.sh` and `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION` in `Chrono.xcodeproj`.

---

## Versioning

Chrono follows [Semantic Versioning](https://semver.org/):

| Component | Meaning |
|-----------|---------|
| **MAJOR** | Breaking changes or major redesign |
| **MINOR** | New features, backward-compatible |
| **PATCH** | Bug fixes and polish |

The **build number** (`CURRENT_PROJECT_VERSION` in Xcode, `BUILD_NUMBER` in `build-dmg.sh`) increments on every shipped build.

---

## Changelog

### 1.0.1 — 2026-05-31

**Fix — popover expansion animation**

- Fixed the info pane expanding upward or jumping during open/close
- Window top edge is now pinned; only the bottom grows and shrinks
- Replaced competing AppKit + SwiftUI frame animations with a single pre-sized AppKit update and a SwiftUI mask reveal
- Pre-measures info pane height via a hidden layout twin so the final size is known before the first tap

### 1.0.0 — Initial release

- Menu bar timer with liquid glass floating panel
- Start / Stop / Reset controls and keyboard shortcuts
- Dynamic status bar pill with tabular digits
- macOS 26–aligned prominent floating element styling

---

## Project layout

| Path | Role |
|------|------|
| `Chrono/ChronoApp.swift` | App entry point |
| `Chrono/MenuBarManager.swift` | AppKit bridge — `NSStatusItem`, borderless `NSPanel`, window sizing |
| `Chrono/TimerPopoverView.swift` | Main popover UI, glass background, info expansion |
| `Chrono/TimerStatusBarView.swift` | Menu bar pill and elapsed time display |
| `Chrono/TimerViewModel.swift` | Timer state and formatting |
| `Chrono/ActivityMonitor.swift` | Idle detection |
| `Chrono/KeyboardShortcutManager.swift` | Global shortcuts |
| `scripts/build-dmg.sh` | Release DMG pipeline |
| `scripts/build-icns.sh` | Icon compilation from `Chrono/assets/icons/` |
| `Chrono.xcodeproj/` | Xcode project |

---

## Architecture (summary)

**MenuBarManager** owns the `NSStatusItem` and a borderless `NSPanel`. SwiftUI reports size changes through `onSizeChange`; AppKit resizes the panel with the top edge fixed.

**TimerPopoverView** hosts controls and the expandable info pane. Expansion uses `infoHeight` mask animation — AppKit receives one final frame before the animation starts, not a stream of intermediate heights.

**TimerStatusBarView** renders inside an `NSHostingView` on the status button. Uses `.monospacedDigit()` and careful sizing so the pill width stays stable as digits change.

See `AGENTS.md` for constraints agents and contributors should follow when changing this codebase.
