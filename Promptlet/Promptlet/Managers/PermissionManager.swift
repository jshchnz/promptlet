//
//  PermissionManager.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import Foundation
import AppKit

@MainActor
class PermissionManager: ObservableObject, PermissionServiceProtocol {
    static let shared = PermissionManager()
    
    @Published var hasAccessibilityPermission = false
    @Published var hasAppleEventsPermission = false
    @Published var isCheckingPermissions = false
    
    private var monitoringTimer: Timer?
    private var permissionChangeCallbacks: [(Bool) -> Void] = []
    
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
        let previousState = hasAccessibilityPermission
        hasAccessibilityPermission = AXIsProcessTrustedWithOptions(options)
        
        // Notify callbacks if permission state changed
        if previousState != hasAccessibilityPermission {
            logInfo(.permission, "Accessibility permission changed: \(hasAccessibilityPermission ? "granted" : "revoked")")
            notifyPermissionChange(hasAccessibilityPermission)
        }
    }
    
    func checkAppleEventsPermission() {
        // Check Apple Events permission by trying to execute a simple AppleScript
        let appleScript = NSAppleScript(source: "return true")
        var error: NSDictionary?
        let _ = appleScript?.executeAndReturnError(&error)
        let previousState = hasAppleEventsPermission
        hasAppleEventsPermission = (error == nil)
        
        // Log if permission state changed
        if previousState != hasAppleEventsPermission {
            logInfo(.permission, "Apple Events permission changed: \(hasAppleEventsPermission ? "granted" : "revoked")")
        }
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
    
    // MARK: - Protocol Conformance (PermissionServiceProtocol)
    
    var hasAccessibilityPermissions: Bool {
        hasAccessibilityPermission
    }
    
    func requestAccessibilityPermissions() {
        _ = requestAccessibilityPermission()
    }
    
    func checkPermissionStatus() -> PermissionStatus {
        return permissionStatus
    }
    
    func showPermissionInstructions() {
        let alert = NSAlert()
        alert.messageText = "Accessibility Permission Required"
        alert.informativeText = """
        Promptlet needs accessibility permission to:
        • Insert text into other applications
        • Detect the active application
        • Position text at your cursor
        
        Please grant permission in System Preferences > Security & Privacy > Privacy > Accessibility
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Later")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            openAccessibilityPreferences()
        }
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
        
        logInfo(.permission, "Starting permission monitoring")
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkAllPermissions()
            }
        }
    }
    
    func stopMonitoring() {
        logInfo(.permission, "Stopping permission monitoring")
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
                logDebug(.permission, "App became active, checking permissions")
                self?.checkAllPermissions()
            }
        }
    }
    
    // MARK: - Permission Change Callbacks
    
    func addPermissionChangeCallback(_ callback: @escaping (Bool) -> Void) {
        permissionChangeCallbacks.append(callback)
        logDebug(.permission, "Added permission change callback")
    }
    
    private func notifyPermissionChange(_ hasPermission: Bool) {
        logInfo(.permission, "Notifying \(permissionChangeCallbacks.count) callbacks of permission change")
        for callback in permissionChangeCallbacks {
            callback(hasPermission)
        }
    }
    
    func getDetailedStatus() -> String {
        return "Accessibility: \(hasAccessibilityPermission ? "✓" : "✗"), Apple Events: \(hasAppleEventsPermission ? "✓" : "✗"), Status: \(permissionStatus.description)"
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