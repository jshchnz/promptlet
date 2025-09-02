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
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Combined Quick Slots Section
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Assign prompts to quick slots and trigger them instantly with keyboard shortcuts")
                            .font(.footnote)
                            .foregroundColor(.secondary)
                        
                        // List of quick slots with all info combined
                        VStack(spacing: 1) {
                            ForEach(1...9, id: \.self) { slot in
                                QuickSlotRow(
                                    slot: slot,
                                    promptStore: promptStore,
                                    settings: settings,
                                    editingShortcut: $editingShortcut
                                )
                                
                                if slot < 9 {
                                    Divider()
                                        .padding(.leading, 44)
                                }
                            }
                        }
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                    }
                } label: {
                    Label("Quick Slots", systemImage: "rectangle.grid.3x3")
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

struct QuickSlotRow: View {
    let slot: Int
    @ObservedObject var promptStore: PromptStore
    @ObservedObject var settings: AppSettings
    @Binding var editingShortcut: ShortcutAction?
    @State private var isHovering = false
    
    var assignedPrompt: Prompt? {
        promptStore.prompts.first { $0.quickSlot == slot }
    }
    
    var availablePrompts: [Prompt] {
        promptStore.prompts
            .filter { !$0.isArchived && ($0.quickSlot == nil || $0.quickSlot == slot) }
            .sorted { $0.title < $1.title }
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
    
    var isEditingThisShortcut: Bool {
        editingShortcut == quickSlotAction
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Slot number badge
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(assignedPrompt != nil ? Color.accentColor : Color.gray.opacity(0.2))
                    .frame(width: 32, height: 32)
                
                Text("\(slot)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(assignedPrompt != nil ? .white : .primary)
            }
            
            // Prompt selector - entire area is clickable
            Menu {
                if assignedPrompt != nil {
                    Button("Clear Slot") {
                        clearSlot()
                    }
                    Divider()
                }
                
                if availablePrompts.isEmpty {
                    Button("No prompts available") { }
                        .disabled(true)
                } else {
                    ForEach(availablePrompts) { prompt in
                        Button(action: {
                            assignPromptToSlot(prompt)
                        }) {
                            VStack(alignment: .leading) {
                                Text(prompt.title)
                                if !prompt.tags.isEmpty {
                                    Text(Array(prompt.tags).prefix(3).joined(separator: ", "))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        if let prompt = assignedPrompt {
                            Text(prompt.title)
                                .font(.system(size: 13, weight: .medium))
                                .lineLimit(1)
                                .foregroundColor(.primary)
                            
                            Text(prompt.preview)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("Choose Prompt...")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            
                            Text("Click to assign")
                                .font(.caption)
                                .foregroundColor(.secondary.opacity(0.7))
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .help("Click to assign or clear prompt")
            
            // Keyboard shortcut
            if isEditingThisShortcut {
                ShortcutFieldView(
                    shortcut: Binding(
                        get: { settings.getShortcut(for: quickSlotAction) },
                        set: { newShortcut in
                            settings.updateShortcut(for: quickSlotAction, shortcut: newShortcut)
                            NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
                            editingShortcut = nil
                        }
                    ),
                    isRequired: false
                )
                .frame(width: 120)
            } else {
                if let shortcut = settings.getShortcut(for: quickSlotAction) {
                    Button(action: { editingShortcut = quickSlotAction }) {
                        Text(shortcut.displayString)
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                    .help("Click to edit shortcut")
                } else {
                    Button(action: { editingShortcut = quickSlotAction }) {
                        Text("Set Key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(isHovering ? Color.gray.opacity(0.05) : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
    
    private func clearSlot() {
        guard let prompt = assignedPrompt else { return }
        
        let updatedPrompt = Prompt(
            id: prompt.id,
            title: prompt.title,
            content: prompt.content,
            tags: prompt.tags,
            category: prompt.category,
            defaultEnhancement: prompt.defaultEnhancement,
            variables: prompt.variables,
            isFavorite: prompt.isFavorite,
            isArchived: prompt.isArchived,
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
                category: currentPrompt.category,
                defaultEnhancement: currentPrompt.defaultEnhancement,
                variables: currentPrompt.variables,
                isFavorite: currentPrompt.isFavorite,
                isArchived: currentPrompt.isArchived,
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
            category: prompt.category,
            defaultEnhancement: prompt.defaultEnhancement,
            variables: prompt.variables,
            isFavorite: prompt.isFavorite,
            isArchived: prompt.isArchived,
            quickSlot: slot,
            createdDate: prompt.createdDate,
            lastUsedDate: prompt.lastUsedDate,
            usageCount: prompt.usageCount,
            perAppEnhancements: prompt.perAppEnhancements
        )
        
        promptStore.updatePrompt(updatedPrompt)
    }
}

