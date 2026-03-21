# Agent Execution Context: Chrono (`agent.md`)

When maintaining or extending Chrono, always prioritize the following guidelines:

## 1. AppKit Foundation over Default Elements
- Chrono intentionally bypasses standard macOS `NSPopover` and System Window Chrome objects.
- It uses manually animated borderless `NSPanel` frames to achieve true **macOS 26 Prominent Floating Elements** layout (`26pt` rounded clipShapes and Liquid Glass layers).
- Do not attempt to refactor the popover back into an `NSPopover` or `.popover(isPresented:)` natively. That severely breaks aesthetics.

## 2. Dynamic SwiftUI Resizing 
- Chrono uses complex bidirectional constraints (`onSizeChange` GeometryReader binds traversing back to `MenuBarManager`) to ensure window bounds always beautifully embrace the animating internal `isExpanded` VStack height without snapping weirdly or expanding *upward* (the native macOS flaw).
- Always use `NSAnimationContext.runAnimationGroup` in AppKit synced with `withAnimation` spring curves inside SwiftUI.

## 3. Top-Bar Component Stability
- Do **not** use `fixedSize` randomly across the application without testing `TimerStatusBarView`. The time display heavily depends on `.monospacedDigit()` and precise fixed sizes so as the chronometer ticks upwards, the tracking pill doesn't jitter left and right. 

## 4. Onboarding Removal Finality
- The previous multi-page, heavy asset SwiftUI Onboarding workflow was completely deprecated and destroyed by the maintainer.
- Do not inject logic for auto-launch presentation or splash screens, unless explicitly commanded. Keep app lightweight, menu-bar focused, and instantly responsive.
