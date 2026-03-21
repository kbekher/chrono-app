//
//  ChronoApp.swift
//  Chrono
//
//  Created by Ivan on 15.11.25.
//

import SwiftUI
import AppKit
import UserNotifications
import Combine

@main
struct ChronoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate, NSUserNotificationCenterDelegate {
    private var menuBarManager: MenuBarManager?
    private var viewModel: TimerViewModel?
    private var cancellables: Set<AnyCancellable> = []
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set delegates
        UNUserNotificationCenter.current().delegate = self
        NSUserNotificationCenter.default.delegate = self
        
		// Hide dock icon while running (app will still appear in Launchpad if installed in /Applications)
        NSApp.setActivationPolicy(.accessory)
        
        // Request notification permissions
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification authorization error: \(error)")
            }
        }
        
        // Create and setup menu bar
        let vm = TimerViewModel()
        let mbm = MenuBarManager(viewModel: vm)
        
        // Store references first to prevent deallocation
        self.viewModel = vm
        self.menuBarManager = mbm
        
        // Then setup (which is now async)
        mbm.setup()
    }
    
    // Show notifications even when the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Use all available methods for visibility: banner, sidebar list, and system sound
        completionHandler([.banner, .list, .sound])
    }
    
    // Legacy fallback for foreground presentation
    func userNotificationCenter(_ center: NSUserNotificationCenter, shouldPresent notification: NSUserNotification) -> Bool {
        return true
    }

    
    func applicationWillTerminate(_ notification: Notification) {
        menuBarManager = nil
        viewModel = nil
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Prevent app from showing windows when clicking dock icon (shouldn't appear anyway)
        return false
    }
}
