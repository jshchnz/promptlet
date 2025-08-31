//
//  AppSettings.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import SwiftUI

enum ThemeMode: String, CaseIterable, Codable {
    case light = "Light"
    case dark = "Dark"
    case auto = "Auto"
}

enum DefaultPosition: String, CaseIterable, Codable {
    case center = "Center of Screen"
    case topCenter = "Top Center"
    case remember = "Remember Last Position"
}

@MainActor
class AppSettings: ObservableObject {
    @AppStorage("themeMode") var themeMode: String = ThemeMode.auto.rawValue {
        didSet {
            applyTheme()
        }
    }
    
    @AppStorage("defaultPosition") var defaultPosition: String = DefaultPosition.center.rawValue
    @AppStorage("savedWindowPosition") var savedWindowPosition: String?
    @AppStorage("keyboardShortcutsData") private var keyboardShortcutsData: Data = Data()
    
    @Published var shortcuts: [ShortcutAction: KeyboardShortcut] = [:] {
        didSet {
            saveShortcuts()
        }
    }
    
    var theme: ThemeMode {
        get { ThemeMode(rawValue: themeMode) ?? .auto }
        set { themeMode = newValue.rawValue }
    }
    
    var position: DefaultPosition {
        get { DefaultPosition(rawValue: defaultPosition) ?? .center }
        set { defaultPosition = newValue.rawValue }
    }
    
    init() {
        loadShortcuts()
    }
    
    func applyTheme() {
        switch theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            NSApp.appearance = nil
        }
    }
    
    func resetWindowPosition() {
        savedWindowPosition = nil
        UserDefaults.standard.removeObject(forKey: "PaletteWindowPosition")
    }
    
    // MARK: - Keyboard Shortcuts
    
    private func loadShortcuts() {
        if keyboardShortcutsData.isEmpty {
            // Use default shortcuts if none saved
            shortcuts = KeyboardShortcut.defaultShortcuts
            saveShortcuts()
        } else {
            // Load saved shortcuts
            do {
                shortcuts = try JSONDecoder().decode([ShortcutAction: KeyboardShortcut].self, from: keyboardShortcutsData)
                // Add any missing default shortcuts for new actions
                for (action, defaultShortcut) in KeyboardShortcut.defaultShortcuts {
                    if shortcuts[action] == nil {
                        shortcuts[action] = defaultShortcut
                    }
                }
            } catch {
                print("[AppSettings] Failed to decode shortcuts: \(error)")
                shortcuts = KeyboardShortcut.defaultShortcuts
            }
        }
    }
    
    private func saveShortcuts() {
        do {
            keyboardShortcutsData = try JSONEncoder().encode(shortcuts)
        } catch {
            print("[AppSettings] Failed to encode shortcuts: \(error)")
        }
    }
    
    func resetShortcutsToDefault() {
        shortcuts = KeyboardShortcut.defaultShortcuts
    }
    
    func resetShortcut(for action: ShortcutAction) {
        shortcuts[action] = KeyboardShortcut.defaultShortcuts[action]
    }
    
    func updateShortcut(for action: ShortcutAction, shortcut: KeyboardShortcut?) {
        if let shortcut = shortcut, shortcut.isValid(for: action) {
            // Remove any other actions using this same shortcut
            for (existingAction, existingShortcut) in shortcuts {
                if existingAction != action && 
                   existingShortcut.keyCode == shortcut.keyCode && 
                   existingShortcut.modifierFlags == shortcut.modifierFlags {
                    shortcuts[existingAction] = nil
                }
            }
            shortcuts[action] = shortcut
        } else {
            shortcuts[action] = nil
        }
    }
    
    func getShortcut(for action: ShortcutAction) -> KeyboardShortcut? {
        return shortcuts[action]
    }
}