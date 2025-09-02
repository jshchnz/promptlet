//
//  QuickSlotsSettingsTab.swift
//  Promptlet
//
//  Created by Assistant on 9/1/25.
//

import SwiftUI

struct QuickSlotsSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var promptStore: PromptStore
    @State private var editingShortcut: ShortcutAction?
    @State private var conflictingAction: ShortcutAction?
    
    let quickSlotActions: [ShortcutAction] = [
        .quickSlot1, .quickSlot2, .quickSlot3,
        .quickSlot4, .quickSlot5, .quickSlot6,
        .quickSlot7, .quickSlot8, .quickSlot9
    ]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Prompt Assignment Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Assign prompts to quick slots for instant access")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        // Grid of quick slots
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(1...9, id: \.self) { slot in
                                QuickSlotAssignmentView(
                                    slot: slot,
                                    promptStore: promptStore,
                                    settings: settings
                                )
                            }
                        }
                    }
                } label: {
                    Label("Prompt Assignment", systemImage: "rectangle.grid.3x3")
                }
                .groupBoxStyle(SettingsGroupBoxStyle())
                
                // Keyboard Shortcuts Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Configure keyboard shortcuts for quick slots (all use Command ⌘ modifier by default)")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .padding(.bottom, 12)
                        
                        ForEach(quickSlotActions, id: \.self) { action in
                            QuickSlotShortcutRow(
                                action: action,
                                settings: settings,
                                editingShortcut: $editingShortcut,
                                conflictingAction: $conflictingAction
                            )
                        }
                    }
                } label: {
                    Label("Keyboard Shortcuts", systemImage: "keyboard")
                }
                .groupBoxStyle(SettingsGroupBoxStyle())
                
                // Menu Bar Settings Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Show quick slots in menu bar", isOn: $settings.showQuickSlotsInMenuBar)
                            .disabled(!settings.showMenuBarIcon)
                        
                        HStack {
                            Text("Number of slots to show:")
                            Stepper(value: $settings.menuBarQuickSlotCount, in: 1...5) {
                                Text("\(settings.menuBarQuickSlotCount)")
                                    .frame(width: 30)
                            }
                            .disabled(!settings.showMenuBarIcon || !settings.showQuickSlotsInMenuBar)
                        }
                        
                        Text("Display your first 1-5 quick slot prompts directly in the menu bar for instant access")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                } label: {
                    Label("Menu Bar", systemImage: "menubar.rectangle")
                }
                .groupBoxStyle(SettingsGroupBoxStyle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
    }
}

struct QuickSlotAssignmentView: View {
    let slot: Int
    @ObservedObject var promptStore: PromptStore
    @ObservedObject var settings: AppSettings
    
    var assignedPrompt: Prompt? {
        promptStore.prompts.first { $0.quickSlot == slot }
    }
    
    var availablePrompts: [Prompt] {
        promptStore.prompts.filter { $0.quickSlot == nil || $0.quickSlot == slot }
            .sorted { $0.title < $1.title }
    }
    
    var shortcutString: String {
        if let shortcut = settings.getShortcut(for: quickSlotAction) {
            return shortcut.displayString
        }
        return "Not Set"
    }
    
    var quickSlotAction: ShortcutAction {
        switch slot {
        case 1: return .quickSlot1
        case 2: return .quickSlot2
        case 3: return .quickSlot3
        case 4: return .quickSlot4
        case 5: return .quickSlot5
        case 6: return .quickSlot6
        case 7: return .quickSlot7
        case 8: return .quickSlot8
        case 9: return .quickSlot9
        default: return .quickSlot1
        }
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Slot header
            HStack {
                Label("Slot \(slot)", systemImage: "\(slot).square")
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text(shortcutString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Prompt picker
            Menu {
                Button("None") {
                    clearSlot()
                }
                .disabled(assignedPrompt == nil)
                
                Divider()
                
                ForEach(availablePrompts) { prompt in
                    Button(prompt.title) {
                        assignPromptToSlot(prompt)
                    }
                }
            } label: {
                HStack {
                    if let prompt = assignedPrompt {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(prompt.title)
                                .font(.caption)
                                .lineLimit(1)
                            if !prompt.tags.isEmpty {
                                Text(Array(prompt.tags).joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    } else {
                        Text("Not Assigned")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
    }
    
    private func clearSlot() {
        guard let prompt = assignedPrompt else { return }
        
        let updatedPrompt = Prompt(
            id: prompt.id,
            title: prompt.title,
            content: prompt.content,
            tags: prompt.tags,
            defaultEnhancement: prompt.defaultEnhancement,
            variables: prompt.variables,
            isFavorite: prompt.isFavorite,
            quickSlot: nil,
            createdDate: prompt.createdDate,
            lastUsedDate: prompt.lastUsedDate,
            usageCount: prompt.usageCount,
            perAppEnhancements: prompt.perAppEnhancements
        )
        
        promptStore.updatePrompt(updatedPrompt)
    }
    
    private func assignPromptToSlot(_ prompt: Prompt) {
        // First, clear this slot from any other prompt
        if let currentPrompt = assignedPrompt, currentPrompt.id != prompt.id {
            let clearedPrompt = Prompt(
                id: currentPrompt.id,
                title: currentPrompt.title,
                content: currentPrompt.content,
                tags: currentPrompt.tags,
                defaultEnhancement: currentPrompt.defaultEnhancement,
                variables: currentPrompt.variables,
                isFavorite: currentPrompt.isFavorite,
                quickSlot: nil,
                createdDate: currentPrompt.createdDate,
                lastUsedDate: currentPrompt.lastUsedDate,
                usageCount: currentPrompt.usageCount,
                perAppEnhancements: currentPrompt.perAppEnhancements
            )
            promptStore.updatePrompt(clearedPrompt)
        }
        
        // Then assign the new prompt to this slot
        let updatedPrompt = Prompt(
            id: prompt.id,
            title: prompt.title,
            content: prompt.content,
            tags: prompt.tags,
            defaultEnhancement: prompt.defaultEnhancement,
            variables: prompt.variables,
            isFavorite: prompt.isFavorite,
            quickSlot: slot,
            createdDate: prompt.createdDate,
            lastUsedDate: prompt.lastUsedDate,
            usageCount: prompt.usageCount,
            perAppEnhancements: prompt.perAppEnhancements
        )
        
        promptStore.updatePrompt(updatedPrompt)
    }
}

struct QuickSlotShortcutRow: View {
    let action: ShortcutAction
    @ObservedObject var settings: AppSettings
    @Binding var editingShortcut: ShortcutAction?
    @Binding var conflictingAction: ShortcutAction?
    
    var isEditing: Bool {
        editingShortcut == action
    }
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(action.displayName)
                    .font(.system(size: 13))
                
                Text(action.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            HStack(spacing: 8) {
                if isEditing {
                    ShortcutFieldView(
                        shortcut: Binding(
                            get: { settings.getShortcut(for: action) },
                            set: { newShortcut in
                                settings.updateShortcut(for: action, shortcut: newShortcut)
                                NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
                                editingShortcut = nil
                            }
                        ),
                        isRequired: action == .showPalette
                    )
                    .frame(width: 180)
                } else {
                    if let shortcut = settings.getShortcut(for: action) {
                        Text(shortcut.displayString)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    } else {
                        Text("Not Set")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Button(action: {
                        editingShortcut = action
                    }) {
                        Text("Edit")
                            .font(.caption)
                    }
                    .buttonStyle(.link)
                    
                    if settings.getShortcut(for: action) != nil && action != .showPalette {
                        Button(action: {
                            settings.updateShortcut(for: action, shortcut: nil)
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(isEditing ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(6)
    }
}

// Extension to provide descriptions for quick slot actions
extension ShortcutAction {
    var description: String {
        switch self {
        case .quickSlot1, .quickSlot2, .quickSlot3, .quickSlot4, .quickSlot5,
             .quickSlot6, .quickSlot7, .quickSlot8, .quickSlot9:
            return "Press Command + number to instantly insert this prompt"
        default:
            return ""
        }
    }
}