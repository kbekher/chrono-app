# Agent Execution Context: Chrono

Guidelines for maintaining and extending Chrono. Read this before changing windowing, animation, or menu bar behavior.

---

## Project overview

Chrono is a minimalist macOS menu bar time tracker. It uses a fluid status bar pill and expands into a custom floating panel — not a native `NSPopover` — to achieve macOS 26 prominent floating element styling (26pt corners, liquid glass, no system chrome bleed).

**Version:** 1.0.1 · **Bundle:** `com.bekher.Chrono`

### Core modules

| Module | Responsibility |
|--------|----------------|
| `MenuBarManager` | `NSStatusItem`, borderless `NSPanel`, `onSizeChange` → frame updates, global dismiss monitor |
| `TimerPopoverView` | Controls, info pane, mask-based expansion, `GlassBackground` |
| `TimerStatusBarView` | Menu bar pill; tabular digits; width stability |
| `TimerViewModel` | Elapsed time, start/stop/reset |
| `ActivityMonitor` | Inactivity auto-stop |
| `KeyboardShortcutManager` | Global shortcuts |

### Release tooling

- `scripts/build-dmg.sh` — Release `.app` → `dist/Chrono-<version>.dmg`
- `scripts/build-icns.sh` — PNG slices in `Chrono/assets/icons/` → `build/Chrono.icns`
- Version constants: `scripts/build-dmg.sh` (`VERSION`, `BUILD_NUMBER`) and Xcode `MARKETING_VERSION` / `CURRENT_PROJECT_VERSION`

---

## 1. AppKit foundation over default elements

- Chrono intentionally bypasses standard macOS `NSPopover` and system window chrome.
- It uses a manually positioned borderless `NSPanel` for true **macOS 26 prominent floating elements** layout.
- Do **not** refactor the popover back into `NSPopover` or `.popover(isPresented:)` — that breaks aesthetics and clipping.

---

## 2. Dynamic SwiftUI resizing

- `TimerPopoverView` reports size via `onSizeChange` (GeometryReader) back to `MenuBarManager`.
- **Pin the panel top edge** (`frame.maxY`) when resizing. Only change `origin.y` and `height` so the window grows downward, never upward.
- On info-pane expand: send **one** final size to AppKit **before** the SwiftUI mask animation. Do not stream intermediate heights — that causes jumpy repositioning.
- Do **not** run a competing `NSAnimationContext` frame animation alongside the SwiftUI mask; they run on different clocks and produce visible jumps.
- Use `withAnimation` spring/ease curves inside SwiftUI; AppKit uses instant `setFrame(..., animate: false)` for the pre-sized frame.

---

## 3. Top-bar component stability

- Do **not** add `fixedSize` casually without testing `TimerStatusBarView`.
- The time display depends on `.monospacedDigit()` and precise sizing so the tracking pill does not jitter left/right as digits change.
- `MenuBarManager.resizeStatusItemToFitText()` sets `NSStatusItem` length from measured monospaced text width.

---

## 4. Onboarding removal finality

- The previous multi-page onboarding workflow was removed intentionally.
- Do not add auto-launch splash screens or onboarding flows unless explicitly requested. Keep the app lightweight, menu-bar focused, and instantly responsive.

---

## 5. Documentation and versioning

- User-facing docs live in `README.md` (overview, build, DMG, changelog).
- Bump patch version (e.g. 1.0.1 → 1.0.2) for bug fixes; update `README.md` changelog, `scripts/build-dmg.sh`, and Xcode project version fields together.
