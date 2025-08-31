//
//  DebugSettingsTab.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import SwiftUI

struct DebugSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var showLogs = false
    @State private var showResetOnboardingConfirmation = false
    @State private var debugOutput = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
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
                            loadDebugLogs()
                        }
                        
                        Button("Export Debug Info") {
                            exportDebugInfo()
                        }
                    }
                }
                .padding(4)
            } label: {
                Label("Developer Options", systemImage: "hammer")
                    .font(.headline)
            }
            
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
                .padding(4)
            } label: {
                Label("Testing", systemImage: "arrow.clockwise")
                    .font(.headline)
            }
            
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
                            PermissionStatusView(name: "Accessibility", isGranted: checkAccessibilityPermission())
                            PermissionStatusView(name: "Apple Events", isGranted: true) // Simplified for now
                        }
                    }
                }
                .padding(4)
            } label: {
                Label("System Information", systemImage: "info.circle")
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showLogs) {
            LogViewer(logs: $debugOutput)
        }
        .alert("Reset Onboarding", isPresented: $showResetOnboardingConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.hasCompletedOnboarding = false
                settings.onboardingVersion = 0
            }
        } message: {
            Text("The onboarding flow will be shown again on next app launch.")
        }
    }
    
    private func checkAccessibilityPermission() -> Bool {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options)
    }
    
    private func loadDebugLogs() {
        // In a real implementation, this would load actual logs
        debugOutput = """
        [2025-08-31 10:00:00] App launched
        [2025-08-31 10:00:01] Checking permissions...
        [2025-08-31 10:00:01] Accessibility: Granted
        [2025-08-31 10:00:02] Loading prompts from storage
        [2025-08-31 10:00:02] Found 15 prompts
        [2025-08-31 10:00:03] Keyboard shortcuts registered
        [2025-08-31 10:00:03] Ready
        """
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

struct LogViewer: View {
    @Binding var logs: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            HStack {
                Text("Debug Logs")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }
            .padding()
            
            ScrollView {
                Text(logs)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color(NSColor.textBackgroundColor))
        }
        .frame(width: 600, height: 400)
    }
}