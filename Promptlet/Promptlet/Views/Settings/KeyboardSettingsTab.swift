//
//  KeyboardSettingsTab.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import SwiftUI

struct KeyboardSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedCategory = "Global"
    @State private var showResetConfirmation = false
    
    let categories = [
        ("Global", "globe", [ShortcutAction.showPalette]),
        ("Navigation", "arrow.up.arrow.down", [ShortcutAction.navigateUp, .navigateDown, .closePalette]),
        ("Actions", "command", [ShortcutAction.insertPrompt, .newPrompt]),
        ("Quick Slots", "number.square", [ShortcutAction.quickSlot1, .quickSlot2, .quickSlot3, .quickSlot4, .quickSlot5, .quickSlot6, .quickSlot7, .quickSlot8, .quickSlot9])
    ]
    
    var body: some View {
        HSplitView {
            // Sidebar
            List(selection: $selectedCategory) {
                ForEach(categories, id: \.0) { category, icon, _ in
                    Label(category, systemImage: icon)
                        .tag(category)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 150)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let category = categories.first(where: { $0.0 == selectedCategory }) {
                        ForEach(category.2, id: \.self) { action in
                            ShortcutRow(action: action, settings: settings)
                            
                            if action != category.2.last {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                    
                    HStack {
                        Spacer()
                        Button("Restore Defaults") {
                            showResetConfirmation = true
                        }
                        .controlSize(.regular)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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

struct ShortcutRow: View {
    let action: ShortcutAction
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.displayName)
                    .font(.system(.body))
                
                if let description = getDescription(for: action) {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            ShortcutFieldView(
                shortcut: Binding(
                    get: { settings.getShortcut(for: action) },
                    set: { newShortcut in
                        settings.updateShortcut(for: action, shortcut: newShortcut)
                        NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
                    }
                ),
                isRequired: action == .showPalette
            )
            .frame(width: 140, height: 22)
        }
    }
    
    func getDescription(for action: ShortcutAction) -> String? {
        switch action {
        case .showPalette:
            return "Opens the prompt palette from anywhere"
        case .navigateUp, .navigateDown:
            return nil
        case .closePalette:
            return "Closes the palette without inserting"
        case .insertPrompt:
            return "Inserts the selected prompt"
        case .newPrompt:
            return "Creates a new prompt"
        case .quickSlot1, .quickSlot2, .quickSlot3, .quickSlot4, .quickSlot5, .quickSlot6, .quickSlot7, .quickSlot8, .quickSlot9:
            return "Instantly insert this quick slot prompt"
        }
    }
}