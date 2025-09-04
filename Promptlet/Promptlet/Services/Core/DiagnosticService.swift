//
//  DiagnosticService.swift
//  Promptlet
//
//  Handles diagnostic, debug, and troubleshooting functionality
//

import Cocoa
import Foundation

@MainActor
class DiagnosticService: ObservableObject {
    
    private weak var keyboardController: KeyboardController?
    private weak var permissionService: PermissionManager?
    
    init() {
        logInfo(.app, "DiagnosticService initialized")
    }
    
    // MARK: - Service Registration
    
    func registerServices(
        keyboardController: KeyboardController,
        permissionService: PermissionManager
    ) {
        self.keyboardController = keyboardController
        self.permissionService = permissionService
        logInfo(.app, "Services registered with DiagnosticService")
    }
    
    // MARK: - Keyboard Diagnostics
    
    func showShortcutStatus(appSettings: AppSettings) {
        guard let keyboardController = keyboardController else {
            showErrorAlert(title: "Service Error", message: "Keyboard controller not available")
            return
        }
        
        let status = keyboardController.getHealthStatus()
        let shortcut = appSettings.getShortcut(for: .showPalette)?.displayString ?? "Not configured"
        
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcut Status"
        alert.informativeText = createShortcutStatusMessage(shortcut: shortcut, status: status)
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
        
        logInfo(.diagnostics, "Shortcut status displayed to user")
    }
    
    private func createShortcutStatusMessage(shortcut: String, status: String) -> String {
        return """
        Current Shortcut: \(shortcut)
        Monitor Status: \(status)
        
        If the shortcut isn't working:
        • Try using "Reset Shortcuts" from the menu
        • Check that Accessibility permissions are granted
        • Restart the app if issues persist
        """
    }
    
    func resetShortcuts() {
        guard let keyboardController = keyboardController else {
            showErrorAlert(title: "Service Error", message: "Keyboard controller not available")
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Reset Keyboard Shortcuts"
        alert.informativeText = "This will re-register the global keyboard shortcut monitors. This can help if shortcuts have stopped working."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            logInfo(.keyboard, "User triggered shortcut reset from diagnostics")
            keyboardController.forceReregisterMonitors()
            
            showSuccessAlert(
                title: "Shortcuts Reset",
                message: "Keyboard shortcuts have been reset. Try using your global shortcut now."
            )
        }
    }
    
    // MARK: - Permission Diagnostics
    
    func showPermissionStatus() {
        guard let permissionManager = permissionService else {
            showErrorAlert(title: "Service Error", message: "Permission manager not available")
            return
        }
        
        let status = permissionManager.getDetailedStatus()
        
        let alert = NSAlert()
        alert.messageText = "Permission Status"
        alert.informativeText = createPermissionStatusMessage(status: status)
        alert.alertStyle = .informational
        
        if !permissionManager.allPermissionsGranted {
            alert.addButton(withTitle: "Grant Permissions")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                permissionManager.showPermissionInstructions()
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        logInfo(.diagnostics, "Permission status displayed to user")
    }
    
    private func createPermissionStatusMessage(status: String) -> String {
        return """
        \(status)
        
        Promptlet requires Accessibility permission to:
        • Capture global keyboard shortcuts
        • Insert text at cursor position
        • Switch between applications
        
        If permissions are missing, click "Grant Permissions" to open System Preferences.
        """
    }
    
    // MARK: - Log Diagnostics
    
    func showDebugLogs() {
        let logs = LogService.shared.getLogsAsString()
        
        // Try to create and open a temporary file
        if let logFileURL = createTemporaryLogFile(with: logs) {
            NSWorkspace.shared.open(logFileURL)
            logInfo(.diagnostics, "Debug logs exported and opened")
        } else {
            // Fallback: show logs in alert
            showLogsInAlert(logs: logs)
        }
    }
    
    private func createTemporaryLogFile(with logs: String) -> URL? {
        let tempDir = FileManager.default.temporaryDirectory
        let logFile = tempDir.appendingPathComponent("promptlet_debug_logs_\(Date().timeIntervalSince1970).txt")
        
        do {
            try logs.write(to: logFile, atomically: true, encoding: .utf8)
            return logFile
        } catch {
            logError(.diagnostics, "Failed to export debug logs to file: \(error)")
            return nil
        }
    }
    
    private func showLogsInAlert(logs: String) {
        let alert = NSAlert()
        alert.messageText = "Debug Logs"
        alert.informativeText = "Recent logs (last \(Search.maxDebugLogLines) lines):"
        
        let scrollView = NSScrollView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let textView = NSTextView(frame: scrollView.bounds)
        
        // Show only recent logs to avoid overwhelming the user
        let recentLogs = String(logs.split(separator: "\n")
            .suffix(Search.maxDebugLogLines)
            .joined(separator: "\n"))
        
        textView.string = recentLogs
        textView.isEditable = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        
        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        
        alert.accessoryView = scrollView
        alert.addButton(withTitle: "Copy to Clipboard")
        alert.addButton(withTitle: "Close")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            copyLogsToClipboard(logs: recentLogs)
        }
        
        logInfo(.diagnostics, "Debug logs shown in alert")
    }
    
    private func copyLogsToClipboard(logs: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(logs, forType: .string)
        
        showInfoAlert(
            title: "Logs Copied",
            message: "Debug logs have been copied to your clipboard."
        )
    }
    
    // MARK: - System Health
    
    func performHealthCheck() -> SystemHealthReport {
        var issues: [HealthIssue] = []
        var warnings: [HealthWarning] = []
        
        // Check keyboard controller health
        if let keyboardController = keyboardController {
            let status = keyboardController.getMonitorStatus()
            if !status.global {
                issues.append(.keyboardMonitor("Global monitor not active"))
            }
            if !status.local {
                issues.append(.keyboardMonitor("Local monitor not active"))
            }
            if status.failureCount > 0 {
                warnings.append(.keyboardFailures("Monitor registration failures: \(status.failureCount)"))
            }
        } else {
            issues.append(.serviceUnavailable("Keyboard controller not available"))
        }
        
        // Check permissions
        if let permissionManager = permissionService {
            if !permissionManager.hasAccessibilityPermissions {
                issues.append(.missingPermission("Accessibility permission not granted"))
            }
        } else {
            issues.append(.serviceUnavailable("Permission manager not available"))
        }
        
        // Check log service
        let logCount = LogService.shared.logs.count
        if logCount > Int(Double(Performance.maxLogs) * 0.9) {
            warnings.append(.logOverflow("Log buffer nearly full: \(logCount)/\(Performance.maxLogs)"))
        }
        
        return SystemHealthReport(
            timestamp: Date(),
            issues: issues,
            warnings: warnings,
            isHealthy: issues.isEmpty
        )
    }
    
    func showSystemHealth() {
        let report = performHealthCheck()
        
        let alert = NSAlert()
        alert.messageText = report.isHealthy ? "System Healthy" : "System Issues Detected"
        alert.informativeText = createHealthReportMessage(report: report)
        alert.alertStyle = report.isHealthy ? .informational : .warning
        
        if !report.isHealthy {
            alert.addButton(withTitle: "Fix Issues")
            alert.addButton(withTitle: "Ignore")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                attemptAutoFix(for: report.issues)
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
        
        logInfo(.diagnostics, "System health report shown: \(report.isHealthy ? "Healthy" : "Issues found")")
    }
    
    private func createHealthReportMessage(report: SystemHealthReport) -> String {
        var message = "System Health Report\n"
        message += "Timestamp: \(DateFormatter.localizedString(from: report.timestamp, dateStyle: .short, timeStyle: .medium))\n\n"
        
        if report.isHealthy {
            message += "✅ All systems functioning normally"
        } else {
            message += "Issues found:\n"
            for issue in report.issues {
                message += "❌ \(issue.description)\n"
            }
        }
        
        if !report.warnings.isEmpty {
            message += "\nWarnings:\n"
            for warning in report.warnings {
                message += "⚠️ \(warning.description)\n"
            }
        }
        
        return message
    }
    
    private func attemptAutoFix(for issues: [HealthIssue]) {
        var fixedCount = 0
        
        for issue in issues {
            switch issue {
            case .keyboardMonitor:
                keyboardController?.forceReregisterMonitors()
                fixedCount += 1
            case .missingPermission:
                permissionService?.requestAccessibilityPermissions()
                fixedCount += 1
            case .serviceUnavailable:
                // Cannot auto-fix service availability issues
                break
            }
        }
        
        showInfoAlert(
            title: "Auto-Fix Results",
            message: "Attempted to fix \(fixedCount) out of \(issues.count) issues. Please restart the app if issues persist."
        )
    }
    
    // MARK: - Alert Helpers
    
    private func showErrorAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showSuccessAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showInfoAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Supporting Types

struct SystemHealthReport {
    let timestamp: Date
    let issues: [HealthIssue]
    let warnings: [HealthWarning]
    let isHealthy: Bool
    
    var summary: String {
        if isHealthy {
            return "System is healthy"
        } else {
            return "\(issues.count) issues, \(warnings.count) warnings"
        }
    }
}

enum HealthIssue {
    case keyboardMonitor(String)
    case missingPermission(String)
    case serviceUnavailable(String)
    
    var description: String {
        switch self {
        case .keyboardMonitor(let detail):
            return "Keyboard monitor issue: \(detail)"
        case .missingPermission(let detail):
            return "Permission issue: \(detail)"
        case .serviceUnavailable(let detail):
            return "Service issue: \(detail)"
        }
    }
}

enum HealthWarning {
    case keyboardFailures(String)
    case logOverflow(String)
    case performanceIssue(String)
    
    var description: String {
        switch self {
        case .keyboardFailures(let detail):
            return "Keyboard warning: \(detail)"
        case .logOverflow(let detail):
            return "Logging warning: \(detail)"
        case .performanceIssue(let detail):
            return "Performance warning: \(detail)"
        }
    }
}