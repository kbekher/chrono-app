## Chrono v1.0.0 (First Release)

A lightweight, highly polished macOS menu bar timer meticulously tailored to the macOS 26 design language (Prominent Floating Elements).

### Design Aesthetics & Features
- **Liquid Glass Interface:** Seamlessly adapts to your desktop background with an organic 26pt border radius standard using `NSVisualEffectView (.hudWindow)`.
- **Smart Expansion:** Natively click the info icon to dramatically expand the interface down with a fluid SwiftUI spring animation, synchronized perfectly with AppKit `NSPanel` bounds.
- **Dynamic Sizing Pill:** A custom top-bar pill elegantly dynamically resizes without ever jittering as the timer expands, matching strict system clock and weather typography perfectly (tabular monospaced digits).

### Prerequisites
- macOS 14+ 
- Swift 5.10.x / Xcode 15+

### Build from Terminal
```bash
# Build the application
xcodebuild build -scheme "Chrono" -destination "platform=macOS"
# Launch it
open build/Build/Products/Debug/Chrono.app
```

### Project Layout
- `Chrono/TimerStatusBarView.swift` — Custom SwiftUI menu bar item dynamically injected inside `MenuBarManager`.
- `Chrono/TimerPopoverView.swift` — The beautifully designed, liquid glass control center holding the `TimerViewModel` controls and animated info pane.
- `Chrono/MenuBarManager.swift` — The deeply integrated AppKit bridge utilizing a borderless `NSPanel` to perfectly frame the rounded corner views without native popover bleeding.
- `Chrono.xcodeproj/` — Standard Xcode project registry.
