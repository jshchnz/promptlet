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
    @State private var conflictingActions: Set<ShortcutAction> = []
    
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
                            ShortcutRow(
                                action: action, 
                                settings: settings,
                                hasConflict: conflictingActions.contains(action),
                                onShortcutChanged: { checkForConflicts() }
                            )
                            
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
        .onAppear {
            checkForConflicts()
        }
    }
    
    private func checkForConflicts() {
        var conflicts: Set<ShortcutAction> = []
        var seenShortcuts: [String: ShortcutAction] = [:]
        
        for category in categories {
            for action in category.2 {
                if let shortcut = settings.getShortcut(for: action) {
                    let key = "\(shortcut.keyCode)-\(shortcut.modifierFlags)"
                    if let existingAction = seenShortcuts[key] {
                        conflicts.insert(action)
                        conflicts.insert(existingAction)
                    } else {
                        seenShortcuts[key] = action
                    }
                }
            }
        }
        
        conflictingActions = conflicts
    }
}

struct ShortcutRow: View {
    let action: ShortcutAction
    @ObservedObject var settings: AppSettings
    let hasConflict: Bool
    let onShortcutChanged: () -> Void
    
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
                        onShortcutChanged()
                    }
                ),
                isRequired: action == .showPalette
            )
            .frame(width: 140, height: 22)
            
            if hasConflict {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
                    .help("This shortcut conflicts with another action")
            }
        }
        .background(
            hasConflict ? 
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.1))
                .padding(-4)
            : nil
        )
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