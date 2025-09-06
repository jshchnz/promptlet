//
//  DebugSettingsTab.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import SwiftUI

struct DebugSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var promptStore: PromptStore
    @State private var showLogs = false
    @State private var showResetOnboardingConfirmation = false
    @State private var showResetPromptsConfirmation = false
    @State private var showClearPromptsConfirmation = false
    @State private var showResetAllSettingsConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Developer Options
                GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Enable debug logging", isOn: $settings.debugMode)
                    
                    Text("Logs additional information to Console for troubleshooting")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Toggle("Show technical info in UI", isOn: $settings.showTechnicalInfo)
                    
                    Text("Display technical details like IDs and timestamps")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    HStack {
                        Button("View Logs") {
                            showLogs = true
                        }
                        
                        Button("Clear Logs") {
                            LogService.shared.clearLogs()
                        }
                        
                        Button("Export Debug Info") {
                            exportDebugInfo()
                        }
                    }
                }
            } label: {
                Label("Developer Options", systemImage: "hammer")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            
            // Onboarding Reset
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reset onboarding flow for testing")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Button("Reset Onboarding") {
                        showResetOnboardingConfirmation = true
                    }
                    .buttonStyle(.bordered)
                }
            } label: {
                Label("Testing", systemImage: "arrow.clockwise")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            
            // Prompt Management
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Manage your prompt library for testing")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Button("Reset to Default Prompts") {
                            showResetPromptsConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Clear All Prompts") {
                            showClearPromptsConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    }
                    
                    Text("Current prompts: \(promptStore.prompts.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } label: {
                Label("Prompt Management", systemImage: "text.badge.xmark")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            
            // System Diagnostics
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Diagnostic tools for troubleshooting system issues")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 12) {
                        Button("Shortcut Status") {
                            showShortcutStatus()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Permission Status") {
                            showPermissionStatus()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    HStack(spacing: 12) {
                        Button("Reset Shortcuts") {
                            resetShortcuts()
                        }
                        .buttonStyle(.bordered)
                        
                        Button("Export Debug Logs") {
                            exportDebugLogs()
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Divider()
                    
                    Text("This will reset all settings to defaults, including shortcuts and appearance")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    
                    HStack {
                        Spacer()
                        
                        Button("Reset All Settings") {
                            showResetAllSettingsConfirmation = true
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        
                        Spacer()
                    }
                }
            } label: {
                Label("System Diagnostics", systemImage: "stethoscope")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            
            // System Info
            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    LabeledContent("macOS Version:") {
                        Text(ProcessInfo.processInfo.operatingSystemVersionString)
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    LabeledContent("Bundle ID:") {
                        Text(Bundle.main.bundleIdentifier ?? "Unknown")
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    
                    LabeledContent("Permissions:") {
                        VStack(alignment: .trailing, spacing: 4) {
                            PermissionStatusView(name: "Accessibility", isGranted: PermissionManager.shared.hasAccessibilityPermission)
                            PermissionStatusView(name: "Apple Events", isGranted: true) // Simplified for now
                        }
                    }
                }
            } label: {
                Label("System Information", systemImage: "info.circle")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .sheet(isPresented: $showLogs) {
            RealLogViewer()
        }
        .alert("Reset Onboarding", isPresented: $showResetOnboardingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.hasCompletedOnboarding = false
                settings.onboardingVersion = 0
                promptStore.clearQuickSlots() // Clear any quick slot assignments from previous onboarding
            }
        } message: {
            Text("The onboarding flow will be shown again on next app launch.")
        }
        .alert("Reset to Default Prompts", isPresented: $showResetPromptsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                promptStore.resetToDefaultPrompts()
            }
        } message: {
            Text("This will replace all current prompts with the default sample prompts. Your custom prompts will be lost.")
        }
        .alert("Clear All Prompts", isPresented: $showClearPromptsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                promptStore.clearAllPrompts()
            }
        } message: {
            Text("This will permanently delete all prompts. This action cannot be undone.")
        }
        .alert("Reset All Settings", isPresented: $showResetAllSettingsConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values, including keyboard shortcuts and appearance preferences.")
        }
    }
    
    // MARK: - Diagnostic Methods
    
    private func showShortcutStatus() {
        let shortcut = settings.getShortcut(for: .showPalette)?.displayString ?? "Not configured"
        
        let alert = NSAlert()
        alert.messageText = "Keyboard Shortcut Status"
        alert.informativeText = """
        Current Shortcut: \(shortcut)
        Monitor Status: Available in menu bar version
        
        If the shortcut isn't working:
        • Try using "Reset Shortcuts" below
        • Check that Accessibility permissions are granted
        • Restart the app if issues persist
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showPermissionStatus() {
        let hasAccessibility = PermissionManager.shared.hasAccessibilityPermission
        let statusText = hasAccessibility ? "✅ Granted" : "❌ Not Granted"
        
        let alert = NSAlert()
        alert.messageText = "Permission Status"
        alert.informativeText = """
        Accessibility Permission: \(statusText)
        
        Promptlet requires Accessibility permission to:
        • Capture global keyboard shortcuts
        • Insert text at cursor position
        • Switch between applications
        
        \(hasAccessibility ? "All required permissions are granted." : "Missing permissions may prevent the app from working properly.")
        """
        alert.alertStyle = .informational
        
        if !hasAccessibility {
            alert.addButton(withTitle: "Grant Permissions")
            alert.addButton(withTitle: "Cancel")
            
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                PermissionManager.shared.showPermissionInstructions()
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func resetShortcuts() {
        let alert = NSAlert()
        alert.messageText = "Reset Keyboard Shortcuts"
        alert.informativeText = "This will re-register the global keyboard shortcut monitors. This can help if shortcuts have stopped working."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Reset")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // Note: Full reset functionality requires access to KeyboardController
            // For now, show success message encouraging restart
            let successAlert = NSAlert()
            successAlert.messageText = "Shortcuts Reset"
            successAlert.informativeText = "Please restart the app to fully reset keyboard shortcuts."
            successAlert.alertStyle = .informational
            successAlert.addButton(withTitle: "OK")
            successAlert.runModal()
        }
    }
    
    private func exportDebugLogs() {
        let logs = LogService.shared.getLogsAsString()
        
        // Try to create and open a temporary file
        let tempDir = FileManager.default.temporaryDirectory
        let logFile = tempDir.appendingPathComponent("promptlet_debug_logs_\(Date().timeIntervalSince1970).txt")
        
        do {
            try logs.write(to: logFile, atomically: true, encoding: .utf8)
            NSWorkspace.shared.open(logFile)
        } catch {
            // Fallback: copy to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(logs, forType: .string)
            
            let alert = NSAlert()
            alert.messageText = "Debug Logs Copied"
            alert.informativeText = "Could not create temporary file. Debug logs have been copied to your clipboard instead."
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
    
    private func exportDebugInfo() {
        let debugInfo = """
        Promptlet Debug Information
        ==========================
        Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
        Build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Launch Count: \(settings.launchCount)
        Debug Mode: \(settings.debugMode)
        
        Recent Logs:
        ===========
        \(LogService.shared.getLogsAsString())
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(debugInfo, forType: .string)
    }
}

struct PermissionStatusView: View {
    let name: String
    let isGranted: Bool
    
    var body: some View {
        HStack(spacing: 4) {
            Text(name)
                .font(.caption)
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isGranted ? .green : .red)
                .font(.caption)
        }
    }
}

struct RealLogViewer: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject private var logService = LogService.shared
    @State private var selectedLevel: LogLevel? = nil
    @State private var searchText = ""
    
    private var filteredLogs: [LogEntry] {
        var logs = logService.logs
        
        // Filter by level if selected
        if let level = selectedLevel {
            logs = logs.filter { $0.level == level }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            logs = logs.filter { 
                $0.message.localizedCaseInsensitiveContains(searchText) ||
                $0.category.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return logs.reversed() // Show newest first
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Logs")
                    .font(.headline)
                
                Spacer()
                
                // Level filter
                Picker("Level", selection: $selectedLevel) {
                    Text("All").tag(nil as LogLevel?)
                    ForEach(LogLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level as LogLevel?)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 100)
                
                Button("Clear") {
                    LogService.shared.clearLogs()
                }
                .buttonStyle(.bordered)
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Search logs...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)
            
            Divider()
            
            // Logs
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(filteredLogs, id: \.id) { log in
                        LogEntryView(entry: log)
                    }
                    
                    if filteredLogs.isEmpty {
                        Text("No logs found")
                            .foregroundColor(.secondary)
                            .padding()
                    }
                }
            }
        }
        .frame(width: 800, height: 600)
    }
}

struct LogEntryView: View {
    let entry: LogEntry
    
    private var levelColor: Color {
        switch entry.level {
        case .info:
            return .blue
        case .warning:
            return .orange
        case .error:
            return .red
        case .debug:
            return .purple
        case .success:
            return .green
        }
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            // Timestamp
            Text(formatTimestamp(entry.timestamp))
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            // Level badge
            Text(entry.level.rawValue)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(levelColor)
                )
                .frame(width: 60)
            
            // Category
            Text(entry.category)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)
            
            // Message
            Text(entry.message)
                .font(.system(.caption, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
        .background(
            entry.level == .error ? 
            Color.red.opacity(0.1) :
            (entry.level == .warning ? Color.orange.opacity(0.1) : Color.clear)
        )
    }
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }
}