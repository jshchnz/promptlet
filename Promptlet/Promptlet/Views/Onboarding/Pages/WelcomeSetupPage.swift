//
//  WelcomeSetupPage.swift
//  Promptlet
//
//  Welcome and shortcut setup - no scrolling, fixed layout
//

import SwiftUI

struct WelcomeSetupPage: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedPreset = 0
    @State private var customShortcut: KeyboardShortcut?
    
    private let presets = [
        ("⌘⇧Space", KeyboardShortcut(keyCode: 49, modifierFlags: NSEvent.ModifierFlags([.command, .shift]).rawValue)),
        ("⌃⇧P", KeyboardShortcut(keyCode: 35, modifierFlags: NSEvent.ModifierFlags([.control, .shift]).rawValue)),
        ("⌥⌘P", KeyboardShortcut(keyCode: 35, modifierFlags: NSEvent.ModifierFlags([.option, .command]).rawValue))
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 50)
            
            // App icon - 80x80
            Image(systemName: "command.square.fill")
                .font(.system(size: 56))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accent, Color.accent.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)
            
            Spacer()
                .frame(height: 24)
            
            // Title and description
            VStack(spacing: 8) {
                Text("Welcome to Promptlet")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text("Your AI prompts, one shortcut away")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
                .frame(height: 40)
            
            // Shortcut setup section
            VStack(spacing: 16) {
                Text("Choose your activation shortcut")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                
                // Preset buttons
                HStack(spacing: 12) {
                    ForEach(0..<presets.count, id: \.self) { index in
                        PresetButton(
                            keys: presets[index].0,
                            isSelected: selectedPreset == index,
                            action: {
                                selectedPreset = index
                                settings.updateShortcut(for: .showPalette, shortcut: presets[index].1)
                                NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
                            }
                        )
                    }
                }
                
                // Custom option
                HStack(spacing: 12) {
                    Text("or custom:")
                        .font(.system(size: 12))
                        .foregroundColor(.secondaryText)
                    
                    ShortcutFieldView(
                        shortcut: Binding(
                            get: { customShortcut ?? settings.getShortcut(for: .showPalette) },
                            set: { newShortcut in
                                customShortcut = newShortcut
                                settings.updateShortcut(for: .showPalette, shortcut: newShortcut)
                                selectedPreset = -1
                            }
                        ),
                        isRequired: true
                    )
                    .frame(width: 150, height: 28)
                }
            }
            .padding(.horizontal, 60)
            
            Spacer()
                .frame(height: 40)
            
            // Footer hint
            Text("You can change this anytime in Settings")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
            
            Spacer()
        }
        .frame(width: 600, height: 390)
        .onAppear {
            // Set default shortcut if none exists
            if settings.getShortcut(for: .showPalette) == nil {
                selectedPreset = 0
                settings.updateShortcut(for: .showPalette, shortcut: presets[0].1)
                NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
            }
        }
    }
}

// Simplified preset button
struct PresetButton: View {
    let keys: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(keys)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(isSelected ? .white : .primaryText)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accent : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.clear : Color.divider, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
    }
}