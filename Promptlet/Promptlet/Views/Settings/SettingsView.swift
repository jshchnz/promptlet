//
//  SettingsView.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var promptStore: PromptStore
    var appDelegate: AppDelegate
    @State private var selectedTab = "general"
    
    var body: some View {
        VStack(spacing: 0) {
            // macOS-style toolbar
            HStack(spacing: 12) {
                ToolbarButton(
                    title: "General",
                    icon: "gearshape",
                    tag: "general",
                    selection: $selectedTab
                )
                .accessibilityIdentifier("general-settings-tab")
                
                ToolbarButton(
                    title: "Keyboard",
                    icon: "keyboard",
                    tag: "keyboard",
                    selection: $selectedTab
                )
                .accessibilityIdentifier("keyboard-settings-tab")
                
                ToolbarButton(
                    title: "Organization",
                    icon: "folder",
                    tag: "organization",
                    selection: $selectedTab
                )
                .accessibilityIdentifier("organization-settings-tab")
                
                ToolbarButton(
                    title: "Quick Slots",
                    icon: "rectangle.grid.3x3",
                    tag: "quickslots",
                    selection: $selectedTab
                )
                .accessibilityIdentifier("quickslots-settings-tab")
                
                ToolbarButton(
                    title: "Debug",
                    icon: "hammer",
                    tag: "debug",
                    selection: $selectedTab
                )
                .accessibilityIdentifier("debug-settings-tab")
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            
            Divider()
            
            // Content area
            Group {
                switch selectedTab {
                case "general":
                    GeneralSettingsTab(settings: settings)
                case "keyboard":
                    KeyboardSettingsTab(settings: settings)
                case "organization":
                    OrganizationSettingsTab(settings: settings, promptStore: promptStore)
                case "quickslots":
                    QuickSlotsSettingsTab(settings: settings, promptStore: promptStore)
                case "debug":
                    DebugSettingsTab(settings: settings, promptStore: promptStore, appDelegate: appDelegate)
                default:
                    GeneralSettingsTab(settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 900, height: 650)
    }
}

struct ToolbarButton: View {
    let title: String
    let icon: String
    let tag: String
    @Binding var selection: String
    
    var isSelected: Bool {
        selection == tag
    }
    
    var body: some View {
        Button(action: {
            selection = tag
        }) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .frame(width: 80, height: 50)
            .contentShape(Rectangle())
        }
        .accessibilityLabel("\(title) settings")
        .accessibilityHint("Switch to \(title.lowercased()) settings tab")
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.gray.opacity(0.2) : Color.clear)
        )
    }
}

#Preview {
    SettingsView(settings: AppSettings(), promptStore: PromptStore(), appDelegate: AppDelegate())
}