//
//  AppearanceSettingsTab.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import SwiftUI

struct AppearanceSettingsTab: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Theme Settings
                GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("Appearance:") {
                        Picker("", selection: $settings.themeMode) {
                            ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                                Text(mode.rawValue).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }
                    
                    Text("Promptlet automatically adjusts to match your system appearance")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            
            // Visual Effects
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    Toggle("Enable window animations", isOn: $settings.enableAnimations)
                    
                    Text("Smooth fade and scale animations when showing/hiding windows")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    Divider()
                    
                    Toggle("Show menu bar icon", isOn: $settings.showMenuBarIcon)
                    
                    Text("Display Promptlet icon in the menu bar for quick access")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            } label: {
                Label("Visual Effects", systemImage: "sparkles")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
}