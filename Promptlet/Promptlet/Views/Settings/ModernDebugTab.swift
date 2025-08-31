//
//  ModernDebugTab.swift
//  Promptlet
//
//  Developer settings with clean design
//

import SwiftUI

struct ModernDebugTab: View {
    @ObservedObject var settings: AppSettings
    @State private var showLogs = false
    @State private var showResetOnboardingConfirmation = false
    @State private var copiedToClipboard = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Developer Options
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader("Developer Options", icon: "hammer.fill")
                    
                    VStack(spacing: Spacing.md) {
                        SettingsRow("Debug Logging", icon: "doc.text.magnifyingglass") {
                            Toggle("", isOn: $settings.debugMode)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        
                        SettingsRow("Technical Info", icon: "info.square") {
                            Toggle("", isOn: $settings.showTechnicalInfo)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        
                        Divider()
                        
                        HStack(spacing: Spacing.md) {
                            Button("View Logs") {
                                showLogs = true
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            
                            Button(copiedToClipboard ? "Copied!" : "Export Debug Info") {
                                exportDebugInfo()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .disabled(copiedToClipboard)
                        }
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                            .fill(Color.secondaryBackground.opacity(0.5))
                    )
                }
                
                // Testing Tools
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader("Testing", icon: "wrench.and.screwdriver.fill")
                    
                    AnimatedCard {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            Text("Reset onboarding to test the flow again")
                                .font(Typography.caption())
                                .foregroundColor(.secondaryText)
                            
                            Button("Reset Onboarding") {
                                showResetOnboardingConfirmation = true
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                        }
                    }
                }
                
                // System Information
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader("System Information", icon: "cpu")
                    
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        SystemInfoRow(label: "macOS", value: ProcessInfo.processInfo.operatingSystemVersionString)
                        SystemInfoRow(label: "Bundle ID", value: Bundle.main.bundleIdentifier ?? "Unknown")
                        SystemInfoRow(label: "Architecture", value: getArchitecture())
                        
                        Divider()
                        
                        // Permissions status
                        HStack {
                            Text("Permissions")
                                .font(Typography.body())
                                .foregroundColor(.secondaryText)
                            
                            Spacer()
                            
                            HStack(spacing: Spacing.md) {
                                PermissionBadge(
                                    name: "Accessibility",
                                    isGranted: checkAccessibilityPermission()
                                )
                                
                                PermissionBadge(
                                    name: "Events",
                                    isGranted: true
                                )
                            }
                        }
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                            .fill(Color.secondaryBackground.opacity(0.5))
                    )
                }
            }
            .padding(Spacing.lg)
        }
        .sheet(isPresented: $showLogs) {
            LogViewerSheet()
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
    
    private func getArchitecture() -> String {
        #if arch(arm64)
        return "Apple Silicon"
        #else
        return "Intel"
        #endif
    }
    
    private func exportDebugInfo() {
        let debugInfo = """
        Promptlet Debug Information
        ==========================
        Version: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
        Build: \(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
        macOS: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: \(getArchitecture())
        Launch Count: \(settings.launchCount)
        Debug Mode: \(settings.debugMode)
        Theme: \(settings.themeMode)
        """
        
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(debugInfo, forType: .string)
        
        withAnimation(Animation.spring) {
            copiedToClipboard = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation(Animation.spring) {
                copiedToClipboard = false
            }
        }
    }
}

// MARK: - System Info Row
struct SystemInfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(Typography.body())
                .foregroundColor(.secondaryText)
            
            Spacer()
            
            Text(value)
                .font(Typography.monospaced())
                .foregroundColor(.primaryText)
                .textSelection(.enabled)
        }
    }
}

// MARK: - Permission Badge
struct PermissionBadge: View {
    let name: String
    let isGranted: Bool
    
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: isGranted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12))
                .foregroundColor(isGranted ? .success : .error)
            
            Text(name)
                .font(Typography.caption())
                .foregroundColor(.primaryText)
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                .fill((isGranted ? Color.success : Color.error).opacity(0.1))
        )
    }
}

// MARK: - Log Viewer Sheet
struct LogViewerSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var logs = "Loading logs..."
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Debug Logs")
                    .font(Typography.headline())
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
            .padding(Spacing.lg)
            
            Divider()
            
            // Log content
            ScrollView {
                Text(logs)
                    .font(Typography.monospaced())
                    .foregroundColor(.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(Spacing.lg)
                    .textSelection(.enabled)
            }
            .background(Color.secondaryBackground)
        }
        .frame(width: 700, height: 500)
        .background(VisualEffectBackground())
        .onAppear {
            loadLogs()
        }
    }
    
    private func loadLogs() {
        // Simulate loading logs
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            logs = """
            [2025-08-31 10:00:00.123] INFO: Application launched
            [2025-08-31 10:00:00.456] INFO: Checking permissions...
            [2025-08-31 10:00:00.789] SUCCESS: Accessibility permission granted
            [2025-08-31 10:00:01.012] INFO: Loading prompts from storage
            [2025-08-31 10:00:01.345] INFO: Found 15 prompts
            [2025-08-31 10:00:01.678] INFO: Registering keyboard shortcuts
            [2025-08-31 10:00:01.901] SUCCESS: Global hotkey registered
            [2025-08-31 10:00:02.234] INFO: Application ready
            [2025-08-31 10:05:15.567] INFO: Palette opened
            [2025-08-31 10:05:18.890] INFO: Prompt inserted: "Default Template"
            [2025-08-31 10:05:19.123] INFO: Palette closed
            """
        }
    }
}