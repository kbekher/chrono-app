//
//  TimerPopoverView.swift
//  Chrono
//
//  Created by Ivan on 15.11.25.
//

import SwiftUI
import CoreText
import AppKit

struct TimerPopoverView: View {
    @ObservedObject var viewModel: TimerViewModel

    @State private var infoHeight: CGFloat = 0
    @State private var infoNaturalHeight: CGFloat = 0
    @State private var showContent: Bool = false
    @State private var collapsedHeight: CGFloat = 160
    // Gates all onChange(of: geo.size) callbacks during expand/collapse animation.
    // Without this, every interpolated SwiftUI frame fires onSizeChange, causing
    // AppKit to repeatedly reposition the window mid-animation → visible jump.
    @State private var suppressSizeChanges: Bool = false

    var onSizeChange: ((CGSize) -> Void)? = nil
    private let windowCornerRadius: CGFloat = 26

    private var isExpanded: Bool { infoHeight > 0 }

    // MARK: - Info content extracted so it can be rendered twice:
    // once visibly (clipped, animated) and once invisibly (full height, for measurement).
    // This guarantees infoNaturalHeight is always valid before the first tap —
    // the GeometryReader inside .frame(height: 0) never fires, so measuring
    // from a hidden twin outside the clip is the only reliable approach.
    @ViewBuilder
    private var infoContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Chrono")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("Your minimal time-tracking companion.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Always in Your Menu Bar")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("Track time instantly from the top of your screen.\nStart, stop, or reset with clean and simple controls.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("Control Chrono without lifting your hands.\n⇧⌘S — Start / Stop\n⇧⌘R — Reset")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Smart Auto-Pause")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                Text("Chrono pauses when you're away or your Mac sleeps.")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 24)
        .fixedSize(horizontal: false, vertical: true)
    }

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Title & Info button
            ZStack(alignment: .top) {
                Text("Chrono")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(white: 0.65))
                    .padding(.top, 8)

                HStack {
                    Spacer()
                    InfoButton {
                        handleInfoTap()
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
            }
            .frame(maxWidth: .infinity)

            // MARK: Time display
            Text(viewModel.formattedTimeForPopover())
                .font(tabularNumberFont(size: 34, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 2)

            // MARK: Buttons
            HStack(spacing: 8) {
                HoverButton(
                    title: viewModel.isRunning ? "Stop" : "Start",
                    cornerRadius: 45,
                    action: {
                        if viewModel.isRunning { viewModel.stop() } else { viewModel.start() }
                    }
                )
                HoverButton(
                    title: "Reset",
                    cornerRadius: 30,
                    action: { viewModel.reset() }
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 12)

            // MARK: Animated info panel
            // The visible copy: clipped to infoHeight, fades in/out.
            infoContent
                .opacity(showContent ? 1 : 0)
                .frame(height: infoHeight, alignment: .top)
                .clipped()
        }
        // MARK: Collapsed-height measurement
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear {
                        // Lock collapsedHeight on first render (infoHeight == 0 here).
                        collapsedHeight = geo.size.height
                        onSizeChange?(geo.size)
                    }
                    .onChange(of: geo.size) { newSize in
                        guard !suppressSizeChanges else { return }
                        onSizeChange?(newSize)
                    }
            }
        )
        // MARK: Hidden measuring twin for infoNaturalHeight
        // Rendered at full natural height but invisible and non-interactive,
        // positioned just below the collapsed area so it doesn't affect layout.
        // This is the only reliable way to know the expanded height before the
        // first tap — GeometryReader inside .frame(height: 0) reports 0 or never fires.
        .overlay(alignment: .top) {
            infoContent
                .opacity(0)
                .allowsHitTesting(false)
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .onAppear { infoNaturalHeight = geo.size.height }
                            .onChange(of: geo.size) { size in
                                // Only update when collapsed so we don't corrupt a live animation.
                                if !isExpanded { infoNaturalHeight = size.height }
                            }
                    }
                )
                .offset(y: collapsedHeight)
        }
        .frame(maxHeight: .infinity, alignment: .top)
        .frame(width: 360)
        .background(
            Group {
                if #available(macOS 26, *) {
                    GlassBackground()
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous))
        // Mask grows from collapsedHeight → collapsedHeight + infoNaturalHeight.
        // SwiftUI interpolates infoHeight every display frame, so the rounded
        // bottom corner tracks the window edge exactly with no gap or overshoot.
        .mask(alignment: .top) {
            RoundedRectangle(cornerRadius: windowCornerRadius, style: .continuous)
                .frame(height: collapsedHeight + infoHeight)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopoverDidClose"))) { _ in
            // Reset without animation when popover is dismissed externally.
            infoHeight = 0
            showContent = false
            suppressSizeChanges = false
        }
    }

    // MARK: - Info tap handler
    private func handleInfoTap() {
        if !isExpanded {
            expand()
        } else {
            collapse()
        }
    }

    private func expand() {
        // Suppress all intermediate onChange callbacks — AppKit must not receive
        // a stream of growing heights or it repositions the window on every frame.
        suppressSizeChanges = true

        // Tell AppKit the FINAL size in one atomic call BEFORE the SwiftUI animation
        // starts. The caller is responsible for pinning window.frame.maxY (the top
        // edge) when it handles onSizeChange — a single setFrame(frame, display: true)
        // with origin.y = oldMaxY - newHeight keeps the top locked.
        // Doing this pre-animation means AppKit makes exactly one reposition move,
        // and the SwiftUI mask animation plays entirely inside the already-correct frame.
        let finalSize = CGSize(width: 360, height: collapsedHeight + infoNaturalHeight)
        onSizeChange?(finalSize)

        // Animate the visual mask growing downward.
        withAnimation(.easeInOut(duration: 0.25)) {
            infoHeight = infoNaturalHeight
        }
        // Fade content in slightly after the reveal begins.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
            withAnimation(.easeIn(duration: 0.15)) {
                showContent = true
            }
        }
        // Re-enable size reporting after the full animation completes.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            suppressSizeChanges = false
        }
    }

    private func collapse() {
        suppressSizeChanges = true

        // Fade out content first.
        withAnimation(.easeOut(duration: 0.15)) {
            showContent = false
        }
        // Then shrink the mask.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.easeInOut(duration: 0.25)) {
                infoHeight = 0
            }
        }
        // Tell AppKit the final collapsed size only after the animation finishes —
        // avoids any flicker from AppKit trying to shrink while SwiftUI is still animating.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.42) {
            onSizeChange?(CGSize(width: 360, height: collapsedHeight))
            suppressSizeChanges = false
        }
    }
}

// MARK: - Glass background

struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.blendingMode = .behindWindow
        if #available(macOS 15.0, *) {
            view.material = .hudWindow
        } else {
            view.material = .menu
        }
        view.isEmphasized = true
        view.alphaValue = 0.85
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.state = .active
        nsView.blendingMode = .behindWindow
        if #available(macOS 15.0, *) {
            nsView.material = .hudWindow
        } else {
            nsView.material = .menu
        }
        nsView.isEmphasized = true
        nsView.alphaValue = 0.85
    }
}

// MARK: - Preview

#if DEBUG
#Preview {
    TimerPopoverView(viewModel: TimerViewModel())
}
#endif

// MARK: - Helpers

/// SF Pro with tabular (monospaced) numbers so digits don't shift width as they change.
fileprivate func tabularNumberFont(size: CGFloat, weight: NSFont.Weight = .regular) -> Font {
    let baseFont = NSFont.systemFont(ofSize: size, weight: weight)
    let fontDescriptor = baseFont.fontDescriptor.addingAttributes([
        .featureSettings: [
            [
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector
            ]
        ]
    ])
    if let font = NSFont(descriptor: fontDescriptor, size: size) {
        return Font(font)
    }
    return Font.system(size: size, weight: .regular, design: .monospaced)
}

// MARK: - HoverButton

struct HoverButton: View {
    let title: String
    let cornerRadius: CGFloat
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .frame(maxWidth: 70)
                .multilineTextAlignment(.center)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(Color.white.opacity(isHovered ? 0.50 : 0.30))
                )
                .contentShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - InfoButton

struct InfoButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            SVGInfoLogo()
                .fill(Color.white.opacity(isHovered ? 0.50 : 0.30), style: FillStyle(eoFill: true))
                .frame(width: 20, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - SVGInfoLogo

struct SVGInfoLogo: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let scale = min(rect.width, rect.height) / 30.0
        let transform = CGAffineTransform(scaleX: scale, y: scale)

        path.addPath(Path { p in
            // Outer circle
            p.move(to: CGPoint(x: 15, y: 27))
            p.addCurve(to: CGPoint(x: 27, y: 15), control1: CGPoint(x: 21.628, y: 27), control2: CGPoint(x: 27, y: 21.628))
            p.addCurve(to: CGPoint(x: 15, y: 3), control1: CGPoint(x: 27, y: 8.372), control2: CGPoint(x: 21.628, y: 3))
            p.addCurve(to: CGPoint(x: 3, y: 15), control1: CGPoint(x: 8.372, y: 3), control2: CGPoint(x: 3, y: 8.372))
            p.addCurve(to: CGPoint(x: 15, y: 27), control1: CGPoint(x: 3, y: 21.628), control2: CGPoint(x: 8.372, y: 27))
            p.closeSubpath()

            // Dot
            p.move(to: CGPoint(x: 13.5, y: 10.5))
            p.addCurve(to: CGPoint(x: 15, y: 9), control1: CGPoint(x: 13.5, y: 9.67), control2: CGPoint(x: 14.17, y: 9))
            p.addCurve(to: CGPoint(x: 16.5, y: 10.5), control1: CGPoint(x: 15.83, y: 9), control2: CGPoint(x: 16.5, y: 9.67))
            p.addCurve(to: CGPoint(x: 15, y: 12), control1: CGPoint(x: 16.5, y: 11.33), control2: CGPoint(x: 15.83, y: 12))
            p.addCurve(to: CGPoint(x: 13.5, y: 10.5), control1: CGPoint(x: 14.17, y: 12), control2: CGPoint(x: 13.5, y: 11.33))
            p.closeSubpath()

            // Stem
            p.move(to: CGPoint(x: 13.125, y: 13.5))
            p.addLine(to: CGPoint(x: 15.375, y: 13.5))
            p.addCurve(to: CGPoint(x: 16.5, y: 14.625), control1: CGPoint(x: 15.998, y: 13.5), control2: CGPoint(x: 16.5, y: 14.002))
            p.addLine(to: CGPoint(x: 16.5, y: 18.75))
            p.addLine(to: CGPoint(x: 16.875, y: 18.75))
            p.addCurve(to: CGPoint(x: 18, y: 19.875), control1: CGPoint(x: 17.498, y: 18.75), control2: CGPoint(x: 18, y: 19.252))
            p.addCurve(to: CGPoint(x: 16.875, y: 21), control1: CGPoint(x: 18, y: 20.498), control2: CGPoint(x: 17.5, y: 21))
            p.addLine(to: CGPoint(x: 13.125, y: 21))
            p.addCurve(to: CGPoint(x: 12, y: 19.875), control1: CGPoint(x: 12.502, y: 21), control2: CGPoint(x: 12, y: 20.498))
            p.addCurve(to: CGPoint(x: 13.125, y: 18.75), control1: CGPoint(x: 12, y: 19.252), control2: CGPoint(x: 12.502, y: 18.75))
            p.addLine(to: CGPoint(x: 14.25, y: 18.75))
            p.addLine(to: CGPoint(x: 14.25, y: 15.75))
            p.addLine(to: CGPoint(x: 13.125, y: 15.75))
            p.addCurve(to: CGPoint(x: 12, y: 14.625), control1: CGPoint(x: 12.502, y: 15.75), control2: CGPoint(x: 12, y: 15.248))
            p.addCurve(to: CGPoint(x: 13.125, y: 13.5), control1: CGPoint(x: 12, y: 14.002), control2: CGPoint(x: 12.502, y: 13.5))
            p.closeSubpath()
        })
        return path.applying(transform)
    }
}