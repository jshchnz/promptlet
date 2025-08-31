//
//  PermissionManager.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import Foundation
import AppKit

@MainActor
class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var hasAccessibilityPermission = false
    @Published var hasAppleEventsPermission = false
    @Published var isCheckingPermissions = false
    
    private var monitoringTimer: Timer?
    
    private init() {
        checkAllPermissions()
        setupAppActivationListener()
    }
    
    deinit {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Permission Checking
    
    func checkAllPermissions() {
        checkAccessibilityPermission()
        checkAppleEventsPermission()
    }
    
    func checkAccessibilityPermission() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
    }
    
    func checkAppleEventsPermission() {
        // Check Apple Events permission by trying to execute a simple AppleScript
        let appleScript = NSAppleScript(source: "return true")
        var error: NSDictionary?
        let _ = appleScript?.executeAndReturnError(&error)
        hasAppleEventsPermission = (error == nil)
    }
    
    // MARK: - Permission Requesting
    
    func requestAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        hasAccessibilityPermission = trusted
        
        if !trusted {
            // Open System Preferences to Accessibility
            openAccessibilityPreferences()
        }
        
        return trusted
    }
    
    func requestAppleEventsPermission() {
        // Apple Events permission will be requested automatically
        // when the app tries to send events to other apps
        hasAppleEventsPermission = true
    }
    
    // MARK: - Helper Methods
    
    func openAccessibilityPreferences() {
        let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefpaneUrl)
    }
    
    func openPrivacyPreferences() {
        let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy")!
        NSWorkspace.shared.open(prefpaneUrl)
    }
    
    var allPermissionsGranted: Bool {
        hasAccessibilityPermission && hasAppleEventsPermission
    }
    
    var permissionStatus: PermissionStatus {
        if allPermissionsGranted {
            return .granted
        } else if hasAccessibilityPermission || hasAppleEventsPermission {
            return .partial
        } else {
            return .denied
        }
    }
    
    // MARK: - Monitoring
    
    func startMonitoringPermissions() {
        // Don't start multiple timers
        guard monitoringTimer == nil else { return }
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAllPermissions()
            }
        }
    }
    
    func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    private func setupAppActivationListener() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkAllPermissions()
            }
        }
    }
}

enum PermissionStatus {
    case granted
    case partial
    case denied
    
    var description: String {
        switch self {
        case .granted:
            return "All permissions granted"
        case .partial:
            return "Some permissions missing"
        case .denied:
            return "Permissions required"
        }
    }
    
    var color: NSColor {
        switch self {
        case .granted:
            return .systemGreen
        case .partial:
            return .systemYellow
        case .denied:
            return .systemRed
        }
    }
}