//
//  ModernSettingsView.swift
//  Promptlet
//
//  Native-feeling settings with premium design
//

import SwiftUI

struct ModernSettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedTab = 0
    @State private var showDebugTab = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Custom tab bar
            SettingsTabBar(
                selectedTab: $selectedTab,
                showDebugTab: showDebugTab
            )
            .background(Color.primaryBackground)
            
            Divider()
            
            // Content area
            TabView(selection: $selectedTab) {
                ModernGeneralTab(settings: settings)
                    .tag(0)
                
                ModernKeyboardTab(settings: settings)
                    .tag(1)
                
                ModernAppearanceTab(settings: settings)
                    .tag(2)
                
                if showDebugTab {
                    ModernDebugTab(settings: settings)
                        .tag(3)
                }
            }
            .tabViewStyle(.automatic)
            .background(Color.primaryBackground)
        }
        .frame(width: Layout.maxSettingsWidth, height: Layout.maxSettingsHeight)
        .background(VisualEffectBackground())
        .onAppear {
            // Check if Option key is held to show debug tab
            checkForDebugMode()
        }
    }
    
    private func checkForDebugMode() {
        let flags = NSEvent.modifierFlags
        showDebugTab = flags.contains(.option) || settings.debugMode
    }
}

// MARK: - Custom Tab Bar
struct SettingsTabBar: View {
    @Binding var selectedTab: Int
    let showDebugTab: Bool
    
    private let tabs = [
        ("General", "gearshape.fill"),
        ("Keyboard", "keyboard.fill"),
        ("Appearance", "paintbrush.fill")
    ]
    
    private let debugTab = ("Debug", "hammer.fill")
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<tabs.count, id: \.self) { index in
                SettingsTabButton(
                    title: tabs[index].0,
                    icon: tabs[index].1,
                    isSelected: selectedTab == index,
                    action: { selectedTab = index }
                )
            }
            
            if showDebugTab {
                SettingsTabButton(
                    title: debugTab.0,
                    icon: debugTab.1,
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 }
                )
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }
}

// MARK: - Tab Button
struct SettingsTabButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                
                Text(title)
                    .font(.system(size: 11, weight: isSelected ? .medium : .regular))
            }
            .foregroundColor(isSelected ? .accent : (isHovered ? .primaryText : .secondaryText))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                    .fill(isSelected ? Color.accent.opacity(0.1) : Color.clear)
            )
            .scaleEffect(isHovered && !isSelected ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Modern General Tab
struct ModernGeneralTab: View {
    @ObservedObject var settings: AppSettings
    @State private var showResetConfirmation = false
    @State private var showAbout = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Behavior Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader("Behavior", icon: "gearshape.2")
                    
                    VStack(spacing: Spacing.sm) {
                        SettingsRow("Palette Position", icon: "rectangle.portrait.topleft.inset.filled") {
                            Picker("", selection: $settings.defaultPosition) {
                                ForEach(DefaultPosition.allCases, id: \.rawValue) { position in
                                    Text(position.rawValue).tag(position.rawValue)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 180)
                        }
                        
                        if settings.savedWindowPosition != nil {
                            HStack {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.accent)
                                Text("Custom position saved")
                                    .font(Typography.caption())
                                    .foregroundColor(.secondaryText)
                                Spacer()
                                Button("Reset") {
                                    settings.resetWindowPosition()
                                }
                                .buttonStyle(.plain)
                                .font(Typography.caption())
                                .foregroundColor(.accent)
                            }
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.xs)
                            .background(
                                RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                                    .fill(Color.accent.opacity(0.05))
                            )
                        }
                    }
                    .padding(Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                            .fill(Color.secondaryBackground.opacity(0.5))
                    )
                }
                
                // About Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader("About", icon: "info.circle")
                    
                    AnimatedCard {
                        VStack(alignment: .leading, spacing: Spacing.md) {
                            HStack {
                                Image(systemName: "command.square.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [Color.accent, Color.accent.opacity(0.7)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text("Promptlet")
                                        .font(Typography.headline())
                                    Text("Version \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")")
                                        .font(Typography.caption())
                                        .foregroundColor(.secondaryText)
                                }
                                
                                Spacer()
                                
                                Button("Check for Updates") {
                                    // Check for updates
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            
                            Divider()
                            
                            HStack {
                                Label("\(settings.launchCount) launches", systemImage: "arrow.up.circle")
                                    .font(Typography.caption())
                                    .foregroundColor(.secondaryText)
                                
                                Spacer()
                                
                                Link("Website", destination: URL(string: "https://promptlet.app")!)
                                    .font(Typography.caption())
                            }
                        }
                    }
                }
                
                Spacer(minLength: Spacing.xl)
                
                // Reset button
                HStack {
                    Spacer()
                    Button("Reset All Settings") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .foregroundColor(.error)
                }
            }
            .padding(Spacing.lg)
        }
        .alert("Reset All Settings", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values.")
        }
    }
}