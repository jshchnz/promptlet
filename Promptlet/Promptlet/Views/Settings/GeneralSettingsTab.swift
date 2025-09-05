//
//  GeneralSettingsTab.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import SwiftUI

struct GeneralSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var showResetConfirmation = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                    // Palette Window Settings
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            LabeledContent("Position:") {
                                Picker("", selection: $settings.defaultPosition) {
                                    ForEach(DefaultPosition.allCases, id: \.rawValue) { position in
                                        Text(position.rawValue).tag(position.rawValue)
                                    }
                                }
                                .pickerStyle(.menu)
                                .frame(width: 200)
                            }
                            
                            Text("Choose where the palette window appears when opened")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            if settings.savedWindowPosition != nil {
                                HStack {
                                    Text("Custom position saved")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                    
                                    Button("Clear") {
                                        showResetConfirmation = true
                                    }
                                    .controlSize(.small)
                                }
                            }
                        }
                    } label: {
                        Label("Palette Window", systemImage: "rectangle.stack")
                    }
                    .groupBoxStyle(SettingsGroupBoxStyle())
                
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
                    
                    if settings.showMenuBarIcon {
                        Divider()
                        
                        LabeledContent("Menu bar icon:") {
                            Picker("", selection: Binding(
                                get: { settings.selectedMenuBarIcon },
                                set: { settings.selectedMenuBarIcon = $0 }
                            )) {
                                ForEach(MenuBarIcon.allCases, id: \.rawValue) { icon in
                                    HStack {
                                        Image(systemName: icon.systemImageName)
                                            .frame(width: 16)
                                        Text(icon.displayName)
                                    }
                                    .tag(icon)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 180)
                        }
                        
                        Text("Choose which icon appears in your menu bar")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            } label: {
                Label("Visual Effects", systemImage: "sparkles")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            
            // App Information
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Version:") {
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    LabeledContent("Build:") {
                        Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown")
                            .foregroundColor(.secondary)
                    }
                    
                    LabeledContent("Launch Count:") {
                        Text("\(settings.launchCount)")
                            .foregroundColor(.secondary)
                    }
                }
            } label: {
                Label("App Information", systemImage: "info.circle")
            }
            .groupBoxStyle(SettingsGroupBoxStyle())
            
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .alert("Clear Saved Position", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                settings.resetWindowPosition()
            }
        } message: {
            Text("The palette will return to the default position next time it opens.")
        }
    }
}