//
//  SettingsView.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedTab = "general"
    
    var body: some View {
        VStack(spacing: 0) {
            // macOS-style toolbar
            HStack(spacing: 20) {
                ToolbarButton(
                    title: "General",
                    icon: "gearshape",
                    tag: "general",
                    selection: $selectedTab
                )
                
                ToolbarButton(
                    title: "Keyboard",
                    icon: "keyboard",
                    tag: "keyboard",
                    selection: $selectedTab
                )
                
                ToolbarButton(
                    title: "Appearance",
                    icon: "paintbrush",
                    tag: "appearance",
                    selection: $selectedTab
                )
                
                ToolbarButton(
                    title: "Debug",
                    icon: "hammer",
                    tag: "debug",
                    selection: $selectedTab
                )
            }
            .padding()
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
                case "appearance":
                    AppearanceSettingsTab(settings: settings)
                case "debug":
                    DebugSettingsTab(settings: settings)
                default:
                    GeneralSettingsTab(settings: settings)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 750, height: 550)
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
                    .font(.system(size: 24))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .primary : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isSelected ? Color.gray.opacity(0.2) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView(settings: AppSettings())
}