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
    @State private var isExpanded: Bool = false
    @State private var showContent: Bool = false
    var onSizeChange: ((CGSize) -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            // Title & Info
            ZStack(alignment: .top) {
                Text("Chrono")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(white: 0.65))
                    .padding(.top, 8) // Align mathematically with the top icon padding
                
                HStack {
                    Spacer()
                    InfoButton {
                        if !isExpanded {
                            // Expand height first natively 
                            isExpanded = true
                            
                            // Show text after height expands bounds out structurally 
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.10) {
                                withAnimation(.easeIn(duration: 0.15)) {
                                    showContent = true
                                }
                            }
                        } else {
                            // Hide text first
                            withAnimation(.easeOut(duration: 0.15)) {
                                showContent = false
                            }
                            
                            // Contract height
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                isExpanded = false
                            }
                        }
                    }
                    .padding(.top, 8)
                    .padding(.trailing, 16)
                }
            }
            .frame(maxWidth: .infinity)
            
            // Large time display
            Text(viewModel.formattedTimeForPopover())
                .font(tabularNumberFont(size: 34, weight: .bold))
                .foregroundColor(.white)
                .padding(.top, 2)
            
            // Buttons
            HStack(spacing: 8) {
                // Start/Stop button
                HoverButton(
                    title: viewModel.isRunning ? "Stop" : "Start",
                    cornerRadius: 45,
                    action: {
                        if viewModel.isRunning {
                            viewModel.stop()
                        } else {
                            viewModel.start()
                        }
                    }
                )
                
                // Reset button
                HoverButton(
                    title: "Reset",
                    cornerRadius: 30,
                    action: {
                        viewModel.reset()
                    }
                )
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 6)
            .padding(.bottom, 12)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome to Chrono").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        Text("Your minimal time-tracking companion.").font(.system(size: 12)).foregroundColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Always in Your Menu Bar").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        Text("Track time instantly from the top of your screen.\nStart, stop, or reset with clean and simple controls.").font(.system(size: 12)).foregroundColor(.gray).fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Keyboard Shortcuts").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        Text("Control Chrono without lifting your hands.\n⇧⌘S — Start / Stop\n⇧⌘R — Reset").font(.system(size: 12)).foregroundColor(.gray).fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Smart Auto-Pause").font(.system(size: 13, weight: .bold)).foregroundColor(.white)
                        Text("Chrono pauses when you’re away or your Mac sleeps.").font(.system(size: 12)).foregroundColor(.gray).fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 24)
                .opacity(showContent ? 1 : 0)
            }
        }
        .background(
            GeometryReader { geo in
                Color.clear
                    .onAppear { onSizeChange?(geo.size) }
                    .onChange(of: geo.size) { onSizeChange?($0) }
            }
        )
        .frame(maxHeight: .infinity, alignment: .top) // Expand vertically to bounds
        .frame(width: 360) // Fixed width
        .background(
            Group {
                if #available(macOS 26, *) {
                    GlassBackground()
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                }
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("PopoverDidClose"))) { _ in
            isExpanded = false
            showContent = false
        }
    }
}

// Glass/blur background using NSVisualEffectView for precise control on macOS.
struct GlassBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.state = .active
        view.blendingMode = .behindWindow
        if #available(macOS 15.0, *) {
            // More liquid glass-like material
            view.material = .hudWindow
        } else {
            // Older macOS: classic blurred material
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

#if DEBUG
#Preview {
    TimerPopoverView(viewModel: TimerViewModel())
}
#endif

// Helper function to create SF Pro font with tabular numbers for stable digits
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

// Utility to allow percentage-based corner radius via GeometryReader
private struct GeometryReaderShape<S: Shape>: Shape {
    let builder: @Sendable (CGSize) -> S
    init(_ builder: @escaping @Sendable (CGSize) -> S) {
        self.builder = builder
    }
    func path(in rect: CGRect) -> Path {
        builder(rect.size).path(in: rect)
    }
}

// Custom Hover Button supporting #5e5e5e backgrounds
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

