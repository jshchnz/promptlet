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
    @State private var showResetAllConfirmation = false
    
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
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
                .padding(4)
            } label: {
                Label("Palette Window", systemImage: "rectangle.stack")
                    .font(.headline)
            }
            
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
                .padding(4)
            } label: {
                Label("App Information", systemImage: "info.circle")
                    .font(.headline)
            }
            
                }
                .padding()
            }
            
            // Reset Options (fixed at bottom)
            HStack {
                Spacer()
                
                Button("Reset All Settings") {
                    showResetAllConfirmation = true
                }
                .controlSize(.regular)
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .alert("Clear Saved Position", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                settings.resetWindowPosition()
            }
        } message: {
            Text("The palette will return to the default position next time it opens.")
        }
        .alert("Reset All Settings", isPresented: $showResetAllConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                settings.resetAllSettings()
            }
        } message: {
            Text("This will reset all settings to their default values, including keyboard shortcuts and appearance preferences.")
        }
    }
}