//
//  ModernKeyboardTab.swift
//  Promptlet
//
//  Beautiful keyboard shortcuts settings with visual keyboard
//

import SwiftUI

struct ModernKeyboardTab: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedAction: ShortcutAction? = .showPalette
    @State private var showResetConfirmation = false
    @State private var conflictingShortcut: ShortcutAction?
    
    private let actionGroups: [(String, [ShortcutAction])] = [
        ("Essential", [.showPalette]),
        ("Navigation", [.navigateUp, .navigateDown, .closePalette]),
        ("Actions", [.insertPrompt, .newPrompt]),
        ("Quick Slots", [.quickSlot1, .quickSlot2, .quickSlot3])
    ]
    
    var body: some View {
        HSplitView {
            // Actions list
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    ForEach(actionGroups, id: \.0) { group, actions in
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text(group)
                                .font(Typography.caption())
                                .foregroundColor(.tertiaryText)
                                .textCase(.uppercase)
                                .padding(.horizontal, Spacing.sm)
                            
                            VStack(spacing: 2) {
                                ForEach(actions, id: \.self) { action in
                                    ShortcutActionRow(
                                        action: action,
                                        isSelected: selectedAction == action,
                                        shortcut: settings.getShortcut(for: action),
                                        hasConflict: conflictingShortcut == action,
                                        onSelect: { selectedAction = action }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(Spacing.md)
            }
            .frame(width: 250)
            .background(Color.secondaryBackground.opacity(0.5))
            
            // Detail view
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if let action = selectedAction {
                    // Action details
                    VStack(alignment: .leading, spacing: Spacing.md) {
                        HStack {
                            VStack(alignment: .leading, spacing: Spacing.xs) {
                                Text(action.displayName)
                                    .font(Typography.headline())
                                
                                if let description = action.description {
                                    Text(description)
                                        .font(Typography.caption())
                                        .foregroundColor(.secondaryText)
                                }
                            }
                            
                            Spacer()
                            
                            if action == .showPalette {
                                Label("Required", systemImage: "exclamationmark.circle")
                                    .font(Typography.caption())
                                    .foregroundColor(.warning)
                            }
                        }
                        
                        // Visual keyboard
                        VisualKeyboard(
                            shortcut: Binding(
                                get: { settings.getShortcut(for: action) },
                                set: { newShortcut in
                                    // Check for conflicts
                                    conflictingShortcut = nil
                                    if let newShortcut = newShortcut {
                                        for (_, actions) in actionGroups {
                                            for otherAction in actions where otherAction != action {
                                                if let otherShortcut = settings.getShortcut(for: otherAction),
                                                   otherShortcut.keyCode == newShortcut.keyCode,
                                                   otherShortcut.modifierFlags == newShortcut.modifierFlags {
                                                    conflictingShortcut = otherAction
                                                    break
                                                }
                                            }
                                        }
                                    }
                                    
                                    settings.updateShortcut(for: action, shortcut: newShortcut)
                                    NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
                                }
                            ),
                            isRequired: action == .showPalette
                        )
                        
                        // Conflict warning
                        if conflictingShortcut != nil {
                            HStack(spacing: Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.warning)
                                Text("This shortcut is already in use")
                                    .font(Typography.caption())
                                    .foregroundColor(.warning)
                            }
                            .padding(Spacing.sm)
                            .background(
                                RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                                    .fill(Color.warning.opacity(0.1))
                            )
                            .transition(.scaleAndFade)
                        }
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                            .fill(Color.secondaryBackground)
                    )
                }
                
                Spacer()
                
                // Reset button
                HStack {
                    Button("Restore Defaults") {
                        showResetConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
            }
            .padding(Spacing.lg)
        }
        .alert("Restore Default Shortcuts", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                settings.resetShortcutsToDefault()
                NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
            }
        } message: {
            Text("This will restore all keyboard shortcuts to their default values.")
        }
    }
}

// MARK: - Shortcut Action Row
struct ShortcutActionRow: View {
    let action: ShortcutAction
    let isSelected: Bool
    let shortcut: KeyboardShortcut?
    let hasConflict: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(action.displayName)
                        .font(Typography.body())
                        .foregroundColor(isSelected ? .accent : .primaryText)
                    
                    if let shortcut = shortcut {
                        Text(shortcut.displayString)
                            .font(Typography.monospaced())
                            .foregroundColor(isSelected ? .accent : .secondaryText)
                    } else {
                        Text("Not set")
                            .font(Typography.caption())
                            .foregroundColor(.tertiaryText)
                    }
                }
                
                Spacer()
                
                if hasConflict {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.warning)
                        .font(.system(size: 14))
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                    .fill(isSelected ? Color.accent.opacity(0.1) : (isHovered ? Color.primaryText.opacity(0.05) : Color.clear))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Animation.quick) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Visual Keyboard
struct VisualKeyboard: View {
    @Binding var shortcut: KeyboardShortcut?
    let isRequired: Bool
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: Spacing.md) {
            // Current shortcut display
            HStack {
                Text("Current shortcut:")
                    .font(Typography.body())
                    .foregroundColor(.secondaryText)
                
                if let shortcut = shortcut {
                    HStack(spacing: Spacing.xs) {
                        ForEach(shortcut.visualKeys, id: \.self) { key in
                            KeyboardKey(key, isPressed: true)
                        }
                    }
                } else {
                    Text("None")
                        .font(Typography.body())
                        .foregroundColor(.tertiaryText)
                }
                
                Spacer()
                
                if !isRequired && shortcut != nil {
                    Button("Clear") {
                        shortcut = nil
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.error)
                    .font(Typography.caption())
                }
            }
            
            // Record button
            Button(isRecording ? "Recording..." : "Record New Shortcut") {
                isRecording.toggle()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRecording)
            
            if isRecording {
                Text("Press the key combination you want to use")
                    .font(Typography.caption())
                    .foregroundColor(.secondaryText)
            }
        }
        .padding(Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                .fill(Color.tertiaryBackground.opacity(0.5))
        )
        // Note: onKeyPress is not available in macOS, we'll use the native approach
        .background(
            KeyPressHandler(isRecording: $isRecording, shortcut: $shortcut)
        )
    }
}

// MARK: - Key Press Handler
struct KeyPressHandler: NSViewRepresentable {
    @Binding var isRecording: Bool
    @Binding var shortcut: KeyboardShortcut?
    
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        return view
    }
    
    func updateNSView(_ nsView: NSView, context: Context) {
        // Handle key recording in ShortcutFieldView instead
    }
}

// MARK: - ShortcutAction Extensions
extension ShortcutAction {
    var description: String? {
        switch self {
        case .showPalette:
            return "Opens the prompt palette from anywhere"
        case .navigateUp:
            return "Move selection up in the list"
        case .navigateDown:
            return "Move selection down in the list"
        case .closePalette:
            return "Close palette without inserting"
        case .insertPrompt:
            return "Insert the selected prompt"
        case .newPrompt:
            return "Create a new prompt"
        case .quickSlot1, .quickSlot2, .quickSlot3, .quickSlot4, .quickSlot5,
             .quickSlot6, .quickSlot7, .quickSlot8, .quickSlot9:
            return "Quick access to favorite prompts"
        }
    }
}

extension KeyboardShortcut {
    var visualKeys: [String] {
        var keys: [String] = []
        
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        if flags.contains(.control) { keys.append("⌃") }
        if flags.contains(.option) { keys.append("⌥") }
        if flags.contains(.shift) { keys.append("⇧") }
        if flags.contains(.command) { keys.append("⌘") }
        
        // Add the main key
        if let keyString = keyStringFromCode(keyCode) {
            keys.append(keyString)
        }
        
        return keys
    }
    
    private func keyStringFromCode(_ code: UInt16) -> String? {
        // Common key mappings
        switch code {
        case 49: return "Space"
        case 35: return "P"
        case 36: return "↩"
        case 53: return "⎋"
        case 48: return "⇥"
        case 51: return "⌫"
        case 125: return "↓"
        case 126: return "↑"
        case 123: return "←"
        case 124: return "→"
        case 18...26: return String(code - 17) // Numbers 1-9
        default:
            if let scalar = UnicodeScalar(Int(code)) {
                return String(scalar).uppercased()
            }
            return nil
        }
    }
}