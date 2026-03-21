# Chrono - Project Architecture

## Overview
Chrono is a minimalist menu bar time-tracking companion for macOS. It rests in your status bar as a fluid, dynamically sizing pill, and expands into a gorgeous customized floating popover utilizing deeply integrated macOS 26 user interface concepts (Prominent Floating Elements, 26pt border radii, and Liquid Glass layers).

## Core Architecture

### 1. MenuBarManager (`AppKit` to `SwiftUI` Bridge)
Unlike standard apps using `.popover()` or `NSPopover()`, Chrono manages its own borderless `NSPanel`. This is required to draw completely transparent windows with custom radii because macOS `NSPopover` enforces hardcoded gray backgrounds and structural paddings that interfere with liquid glass clipping.
Furthermore, the MenuBarManager intercepts internal SwiftUI view height changes (`onSizeChange`) and instantly coordinates AppKit `NSAnimationContext` grouping to expand the window's Y-coordinate dynamically downwards.

### 2. TimerPopoverView (`SwiftUI`)
The central control UI. It manages a `TimerViewModel` state interface housing Start/Stop and Reset buttons. It includes:
- **`GlassBackground`**: An `NSVisualEffectView` representable that utilizes `.hudWindow` on macOS 15+ (Liquid Glass approximation).
- Swift `withAnimation` linked to an extensible Info pane hidden out of view unless triggered.

### 3. TimerStatusBarView (`SwiftUI`)
The actual menu bar status item. Wrapped in an `NSHostingView` and set against the `NSStatusItem`'s native button to allow standard click registration, the view restricts its height to 20pt and explicitly commands `.fixedSize(horizontal: true, vertical: false)` so the background pill grows dynamically from `0:00` digits to larger representations without ever clipping text.

### Removing Legacy Complexity
Onboarding UI (welcome frames, TabViews, image assets) was completely stripped out as per project goals, leaving pure, lean menu bar logic focused exclusively on tracking.
