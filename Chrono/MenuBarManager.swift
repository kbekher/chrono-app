//
//  MenuBarManager.swift
//  Chrono
//
//  Created by Ivan on 15.11.25.
//

import AppKit
import SwiftUI
import UserNotifications
import Combine

@MainActor
class MenuBarManager: NSObject, ObservableObject {
    private var statusBarItem: NSStatusItem?
    private var customPopoverWindow: NSPanel?
    private var globalEventMonitor: Any?
    private let viewModel: TimerViewModel
    private let activityMonitor: ActivityMonitor
    private let keyboardShortcutManager: KeyboardShortcutManager
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var hostingView: NSHostingView<AnyView>?
    private lazy var contextMenu: NSMenu = {
        let menu = NSMenu()
        let quitItem = NSMenuItem(title: "Exit", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        return menu
    }()

    init(viewModel: TimerViewModel) {
        self.viewModel = viewModel
        self.activityMonitor = ActivityMonitor()
        self.keyboardShortcutManager = KeyboardShortcutManager()

        super.init()

        setupActivityMonitor()
        setupKeyboardShortcuts()
        setupTimerObserver()
    }

    private func setupTimerObserver() {
        viewModel.$elapsed
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.resizeStatusItemToFitText()
            }
            .store(in: &cancellables)
    }

    private func resizeStatusItemToFitText() {
        guard let button = statusBarItem?.button else { return }
        let timeString = viewModel.formattedTime()

        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = (timeString as NSString).size(withAttributes: attributes).width

        let targetWidth = ceil(width + 16)
        statusBarItem?.length = targetWidth
        button.setFrameSize(NSSize(width: targetWidth, height: button.frame.height))
    }

    func setup() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

            if let button = self.statusBarItem?.button {
                button.title = ""
                button.image = nil
                button.imagePosition = .noImage
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                button.action = #selector(self.togglePopover)
                button.target = self

                let view = TimerStatusBarView(viewModel: self.viewModel).allowsHitTesting(false)
                let hostingView = NSHostingView(rootView: AnyView(view))
                hostingView.translatesAutoresizingMaskIntoConstraints = false
                button.addSubview(hostingView)

                NSLayoutConstraint.activate([
                    hostingView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                    hostingView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
                ])
                self.hostingView = hostingView
            }

            self.resizeStatusItemToFitText()

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
                styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

            panel.contentView = NSHostingView(rootView: TimerPopoverView(
                viewModel: self.viewModel,
                onSizeChange: { [weak panel] newSize in
                    guard let panel = panel else { return }

                    let targetWidth: CGFloat = 360
                    let targetHeight = newSize.height

                    // Pin the TOP edge (maxY) of the existing frame.
                    // Only the bottom grows/shrinks — the top never moves.
                    // No NSAnimationContext: SwiftUI's .mask animation already
                    // provides smooth visual growth. A competing AppKit animation
                    // would run on a different clock and cause the jump.
                    let pinnedMaxY = panel.frame.maxY
                    let newOriginY = pinnedMaxY - targetHeight
                    let newFrame = NSRect(
                        x: panel.frame.origin.x,
                        y: newOriginY,
                        width: targetWidth,
                        height: targetHeight
                    )

                    // setFrame with animate:false is instant and does not fight
                    // SwiftUI. The visual smoothness comes entirely from the mask.
                    panel.setFrame(newFrame, display: true, animate: false)
                }
            ))
            self.customPopoverWindow = panel

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self = self, let panel = self.customPopoverWindow else { return }
                if !panel.isVisible {
                    self.showCustomPopover()
                }
            }

            self.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown]
            ) { [weak self] _ in
                guard let self = self, let panel = self.customPopoverWindow else { return }
                if panel.isVisible {
                    panel.orderOut(nil)
                    NotificationCenter.default.post(
                        name: NSNotification.Name("PopoverDidClose"), object: nil
                    )
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                if self.statusBarItem?.button == nil {
                    self.presentCenteredFallbackWindow()
                }
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.activityMonitor.startMonitoring()
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.keyboardShortcutManager.registerShortcuts()
            }
        }
    }

    private func setupActivityMonitor() {
        activityMonitor.onInactivityDetected = { [weak self] in
            guard let self = self else { return }
            if self.viewModel.isRunning {
                self.viewModel.stop()
                self.sendNotification()
            }
        }
    }

    private func setupKeyboardShortcuts() {
        keyboardShortcutManager.onStartStop = { [weak self] in
            guard let self = self else { return }
            if self.viewModel.isRunning {
                self.viewModel.stop()
            } else {
                self.viewModel.start()
            }
            self.activityMonitor.resetActivity()
        }

        keyboardShortcutManager.onReset = { [weak self] in
            guard let self = self else { return }
            self.viewModel.reset()
            self.activityMonitor.resetActivity()
        }

        keyboardShortcutManager.onQuit = { [weak self] in
            guard self != nil else { return }
            NSApp.terminate(nil)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusBarItem?.button else { return }
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            NSMenu.popUpContextMenu(contextMenu, with: event, for: button)
            return
        }
        guard let panel = customPopoverWindow else { return }

        if panel.isVisible {
            panel.orderOut(nil)
            NotificationCenter.default.post(
                name: NSNotification.Name("PopoverDidClose"), object: nil
            )
        } else {
            showCustomPopover()
        }
    }

    private func showCustomPopover() {
        guard
            let button = statusBarItem?.button,
            let panel = customPopoverWindow,
            let window = button.window
        else { return }

        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(buttonRect)

        let targetWidth: CGFloat = 360
        let targetHeight = panel.contentView?.fittingSize.height ?? panel.frame.height

        let x = screenRect.midX - (targetWidth / 2)
        // Anchor the TOP: bottom of menu bar button minus padding.
        // This is the only place we use the button position — on show, not on resize.
        let y = screenRect.minY - targetHeight - 8

        panel.setFrame(
            NSRect(x: x, y: y, width: targetWidth, height: targetHeight),
            display: false
        )
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func sendNotification() {
        let center = UNUserNotificationCenter.current()

        let content = UNMutableNotificationContent()
        content.title = "Chrono paused"
        content.body = "No activity detected for 5 minutes."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        center.add(request) { error in
            if error != nil {
                let legacyNotification = NSUserNotification()
                legacyNotification.title = "Chrono paused"
                legacyNotification.informativeText = "No activity detected for 5 minutes."
                legacyNotification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(legacyNotification)
            }
        }
    }

    deinit {
        updateTimer?.invalidate()
        cancellables.removeAll()
        activityMonitor.stopMonitoring()
        keyboardShortcutManager.unregisterShortcuts()
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}

// MARK: - Fallback window

extension MenuBarManager {
    private func presentCenteredFallbackWindow() {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 160),
            styleMask: [.titled, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .visible
        panel.titlebarAppearsTransparent = false
        panel.standardWindowButton(.zoomButton)?.isHidden = false
        panel.standardWindowButton(.closeButton)?.isHidden = false
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = false
        panel.level = .statusBar
        panel.isOpaque = true
        panel.backgroundColor = nil
        panel.contentView = NSHostingView(rootView: TimerPopoverView(viewModel: self.viewModel))

        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            let size = panel.frame.size
            let origin = NSPoint(
                x: frame.midX - size.width / 2,
                y: frame.midY - size.height / 2
            )
            panel.setFrameOrigin(origin)
        }

        panel.makeKeyAndOrderFront(nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            panel.orderOut(nil)
        }
    }
}