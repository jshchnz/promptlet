//
//  WelcomeSetupPage.swift
//  Promptlet
//
//  Welcome and shortcut setup - pixel-perfect spacing
//

import SwiftUI

struct WelcomeSetupPage: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedPreset = 0
    @State private var customShortcut: KeyboardShortcut?
    @State private var logoScale: CGFloat = 0.8
    @State private var logoOpacity: Double = 0.0
    
    private let presets = [
        ("⌘⇧.", KeyboardShortcut(keyCode: 47, modifierFlags: NSEvent.ModifierFlags([.command, .shift]).rawValue)),
        ("⌃⇧P", KeyboardShortcut(keyCode: 35, modifierFlags: NSEvent.ModifierFlags([.control, .shift]).rawValue)),
        ("⌥⌘P", KeyboardShortcut(keyCode: 35, modifierFlags: NSEvent.ModifierFlags([.option, .command]).rawValue))
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // Top spacing - 40px
            Spacer()
                .frame(height: 40)
            
            // App icon - 200x200
            Image("promptlet")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 200)
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                .onAppear {
                    // Load-in animation: scale up and fade in
                    withAnimation(
                        .spring(response: 0.8, dampingFraction: 0.6, blendDuration: 0.3)
                        .delay(0.2)
                    ) {
                        logoScale = 1.0
                        logoOpacity = 1.0
                    }
                }
            
            // Spacing - 6px
            Spacer()
                .frame(height: 6)
            
            // Title and description - ~45px
            VStack(spacing: 8) {
                Text("Welcome to Promptlet")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text("Your AI prompts, one shortcut away")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
            }
            
            // Spacing - 35px
            Spacer()
                .frame(height: 35)
            
            // Shortcut setup section - ~100px
            VStack(spacing: 16) {
                Text("Choose your activation shortcut")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                
                // Preset buttons
                HStack(spacing: 12) {
                    ForEach(Array(0..<presets.count), id: \.self) { index in
                        PresetButton(
                            keys: presets[index].0,
                            isSelected: selectedPreset == index,
                            action: {
                                selectedPreset = index
                                customShortcut = nil
                                settings.updateShortcut(for: .showPalette, shortcut: presets[index].1)
                                NotificationCenter.default.post(name: NotificationNames.shortcutsChanged, object: nil)
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
                            get: { 
                                selectedPreset == -1 ? customShortcut : nil
                            },
                            set: { newShortcut in
                                customShortcut = newShortcut
                                settings.updateShortcut(for: .showPalette, shortcut: newShortcut)
                                
                                // Check if new shortcut matches any preset
                                if let newShortcut = newShortcut {
                                    var foundMatch = false
                                    for (index, preset) in presets.enumerated() {
                                        if newShortcut.keyCode == preset.1.keyCode &&
                                           newShortcut.modifierFlags == preset.1.modifierFlags {
                                            selectedPreset = index
                                            customShortcut = nil
                                            foundMatch = true
                                            break
                                        }
                                    }
                                    if !foundMatch {
                                        selectedPreset = -1
                                    }
                                } else {
                                    selectedPreset = -1
                                }
                                
                                NotificationCenter.default.post(name: NotificationNames.shortcutsChanged, object: nil)
                            }
                        ),
                        isRequired: true
                    )
                    .frame(width: 150, height: 28)
                }
            }
            
            // Spacing - 20px
            Spacer()
                .frame(height: 20)
            
            // Footer hint - ~15px
            Text("You can change this anytime in Settings")
                .font(.system(size: 11))
                .foregroundColor(.tertiaryText)
            
            // Bottom spacing - 25px
            Spacer()
                .frame(height: 25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if let existingShortcut = settings.getShortcut(for: .showPalette) {
                // Check if existing shortcut matches any preset
                var foundMatch = false
                for (index, preset) in presets.enumerated() {
                    if existingShortcut.keyCode == preset.1.keyCode &&
                       existingShortcut.modifierFlags == preset.1.modifierFlags {
                        selectedPreset = index
                        foundMatch = true
                        break
                    }
                }
                // If no preset matches, it's a custom shortcut
                if !foundMatch {
                    selectedPreset = -1
                    customShortcut = existingShortcut
                }
            } else {
                // Set default shortcut if none exists
                selectedPreset = 0
                settings.updateShortcut(for: .showPalette, shortcut: presets[0].1)
                NotificationCenter.default.post(name: NotificationNames.shortcutsChanged, object: nil)
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