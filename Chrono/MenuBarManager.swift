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
        // Update menu bar text whenever elapsed time changes
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
        
        // Measure text width for system font 13pt monospaced digit
        let font = NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        let width = (timeString as NSString).size(withAttributes: attributes).width
        
        // Add horizontal padding (8 on each side = 16)
        let targetWidth = ceil(width + 16)
        statusBarItem?.length = targetWidth
        button.setFrameSize(NSSize(width: targetWidth, height: button.frame.height))
    }
    
    func setup() {
        // Create status bar item on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            // Create status bar item using native button title (most reliable visibility)
            self.statusBarItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
            
            // Set up button
            if let button = self.statusBarItem?.button {
                button.title = ""
                button.image = nil
                button.imagePosition = .noImage
                // Receive right-click actions as well
                button.sendAction(on: [.leftMouseUp, .rightMouseUp])
                
                // Set up click handler
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
            
            // Initial map size setup
            self.resizeStatusItemToFitText()
            
            // Create custom borderless panel
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
            panel.contentView = NSHostingView(rootView: TimerPopoverView(viewModel: self.viewModel, onSizeChange: { [weak panel, weak self] newSize in
                guard let panel = panel, let self = self, let button = self.statusBarItem?.button, let window = button.window else { return }
                
                let targetWidth: CGFloat = 360
                let targetHeight = newSize.height
                
                let buttonRect = button.convert(button.bounds, to: nil)
                let screenRect = window.convertToScreen(buttonRect)
                
                let x = screenRect.midX - (targetWidth / 2)
                let y = screenRect.minY - targetHeight - 8
                
                let newFrame = NSRect(x: x, y: y, width: targetWidth, height: targetHeight)
                
                if panel.isVisible && abs(panel.frame.height - targetHeight) > 1 {
                    NSAnimationContext.runAnimationGroup { context in
                        context.duration = 0.25
                        context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        panel.animator().setFrame(newFrame, display: true)
                    }
                } else if !panel.isVisible {
                    panel.setFrame(newFrame, display: false)
                }
            }))
            self.customPopoverWindow = panel
            
            // Auto-open the popover once on first launch
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                guard let self = self, let panel = self.customPopoverWindow else { return }
                if !panel.isVisible {
                    self.showCustomPopover()
                }
            }
            
            // Add global tap monitor to dismiss the custom window
            self.globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                guard let self = self, let panel = self.customPopoverWindow else { return }
                if panel.isVisible {
                    panel.orderOut(nil)
                    NotificationCenter.default.post(name: NSNotification.Name("PopoverDidClose"), object: nil)
                }
            }
            
            // If for any reason the status item didn't attach (very rare or menu bar hidden),
            // present a small floating window centered as a fallback so the user sees the app.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                if self.statusBarItem?.button == nil {
                    self.presentCenteredFallbackWindow()
                }
            }
            
            // Start monitoring - delay to ensure everything is set up
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self else { return }
                self.activityMonitor.startMonitoring()
            }
            
            // Register keyboard shortcuts - delay to ensure app is fully initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                self.keyboardShortcutManager.registerShortcuts()
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
            NotificationCenter.default.post(name: NSNotification.Name("PopoverDidClose"), object: nil)
        } else {
            showCustomPopover()
        }
    }
    
    private func showCustomPopover() {
        guard let button = statusBarItem?.button, let panel = customPopoverWindow, let window = button.window else { return }
        
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = window.convertToScreen(buttonRect)
        
        let targetWidth: CGFloat = 360
        let targetHeight = panel.contentView?.fittingSize.height ?? panel.frame.height
        if panel.frame.size != NSSize(width: targetWidth, height: targetHeight) {
            panel.setContentSize(NSSize(width: targetWidth, height: targetHeight))
        }
        
        let x = screenRect.midX - (targetWidth / 2)
        let y = screenRect.minY - targetHeight - 8 // 8pt padding from menu bar
        
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func sendNotification() {
        let center = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = "Chrono paused"
        content.body = "No activity detected for 5 minutes."
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { error in
            if let error = error {
                
                // FALLBACK: Legacy NSUserNotification
                let legacyNotification = NSUserNotification()
                legacyNotification.title = "Chrono paused"
                legacyNotification.informativeText = "No activity detected for 5 minutes."
                legacyNotification.soundName = NSUserNotificationDefaultSoundName
                NSUserNotificationCenter.default.deliver(legacyNotification)
            } else {
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
        // Use standard system titlebar/border
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
            let origin = NSPoint(x: frame.midX - size.width / 2, y: frame.midY - size.height / 2)
            panel.setFrameOrigin(origin)
        }
        
        panel.makeKeyAndOrderFront(nil)
        
        // Auto-close after a few seconds so it doesn't linger
        DispatchQueue.main.asyncAfter(deadline: .now() + 6.0) {
            panel.orderOut(nil)
        }
    }
}

