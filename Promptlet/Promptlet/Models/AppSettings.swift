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

enum MenuBarIcon: String, CaseIterable, Codable {
    case textQuote = "text.quote"
    case command = "command"
    case docText = "doc.text"
    case textBubble = "text.bubble"
    case searchText = "rectangle.and.text.magnifyingglass"
    
    var displayName: String {
        switch self {
        case .textQuote: return "Quote Marks"
        case .command: return "Command Key"
        case .docText: return "Document"
        case .textBubble: return "Speech Bubble"
        case .searchText: return "Search Text"
        }
    }
    
    var systemImageName: String {
        return self.rawValue
    }
}

@MainActor
class AppSettings: ObservableObject {
    @AppStorage("themeMode") var themeMode: String = ThemeMode.auto.rawValue {
        didSet {
            if oldValue != themeMode {
                trackAnalytics(.themeChanged, properties: [
                    "old_theme": oldValue,
                    "new_theme": themeMode
                ])
            }
            applyTheme()
        }
    }
    
    @AppStorage("defaultPosition") var defaultPosition: String = DefaultPosition.center.rawValue
    @AppStorage("savedWindowPosition") var savedWindowPosition: String?
    @AppStorage("keyboardShortcutsData") private var keyboardShortcutsData: Data = Data()
    
    // Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @AppStorage("onboardingVersion") var onboardingVersion: Int = 0
    @AppStorage("launchCount") var launchCount: Int = 0
    
    // Visual Settings
    @AppStorage("enableAnimations") var enableAnimations: Bool = true {
        didSet {
            if oldValue != enableAnimations {
                trackAnalytics(.animationsToggled, properties: ["enabled": enableAnimations])
            }
        }
    }
    @AppStorage("showMenuBarIcon") var showMenuBarIcon: Bool = true {
        didSet {
            if oldValue != showMenuBarIcon {
                trackAnalytics(.menuBarIconToggled, properties: ["enabled": showMenuBarIcon])
            }
        }
    }
    @AppStorage("showQuickSlotsInMenuBar") var showQuickSlotsInMenuBar: Bool = true
    @AppStorage("menuBarQuickSlotCount") var menuBarQuickSlotCount: Int = 5
    @AppStorage("menuBarIcon") var menuBarIcon: String = MenuBarIcon.textBubble.rawValue
    
    // Debug Settings
    @AppStorage("debugMode") var debugMode: Bool = false {
        didSet {
            if oldValue != debugMode {
                trackAnalytics(.debugModeToggled, properties: ["enabled": debugMode])
            }
        }
    }
    @AppStorage("showTechnicalInfo") var showTechnicalInfo: Bool = false
    
    // Analytics is always enabled - no user setting needed
    
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
    
    var selectedMenuBarIcon: MenuBarIcon {
        get { MenuBarIcon(rawValue: menuBarIcon) ?? .textBubble }
        set { menuBarIcon = newValue.rawValue }
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
                
                // Fix corrupted quick slot shortcuts (missing modifiers)
                let quickSlotActions: [ShortcutAction] = [
                    .quickSlot1, .quickSlot2, .quickSlot3, .quickSlot4, .quickSlot5,
                    .quickSlot6, .quickSlot7, .quickSlot8, .quickSlot9
                ]
                
                var fixedCorruptedShortcuts = false
                for action in quickSlotActions {
                    if let shortcut = shortcuts[action], shortcut.modifierFlags == 0 {
                        // Quick slot shortcut has no modifiers - this is corrupted, restore default
                        logWarning(.settings, "Fixing corrupted shortcut for \(action): restoring default")
                        shortcuts[action] = KeyboardShortcut.defaultShortcuts[action]
                        fixedCorruptedShortcuts = true
                    }
                }
                
                // Save the fixed shortcuts if any were corrupted
                if fixedCorruptedShortcuts {
                    saveShortcuts()
                }
            } catch {
                logError(.settings, "Failed to decode shortcuts: \(error)")
                shortcuts = KeyboardShortcut.defaultShortcuts
            }
        }
    }
    
    private func saveShortcuts() {
        do {
            keyboardShortcutsData = try JSONEncoder().encode(shortcuts)
        } catch {
            logError(.settings, "Failed to encode shortcuts: \(error)")
        }
    }
    
    func resetShortcutsToDefault() {
        trackAnalytics(.shortcutsReset)
        shortcuts = KeyboardShortcut.defaultShortcuts
    }
    
    func resetShortcut(for action: ShortcutAction) {
        shortcuts[action] = KeyboardShortcut.defaultShortcuts[action]
    }
    
    func updateShortcut(for action: ShortcutAction, shortcut: KeyboardShortcut?) {
        // Add safety checks for shortcut updates
        guard Thread.isMainThread else {
            #if DEBUG
            print("[WARNING][Settings] updateShortcut called from background thread, dispatching to main")
            #endif
            DispatchQueue.main.async {
                self.updateShortcut(for: action, shortcut: shortcut)
            }
            return
        }
        
        let oldShortcut = shortcuts[action]
        
        // Safely update shortcut
        if let shortcut = shortcut {
            // Validate shortcut before setting
            guard shortcut.isValid(for: action) else {
                #if DEBUG
                print("[WARNING][Settings] Invalid shortcut for action \(action.rawValue), ignoring update")
                #endif
                return
            }
            
            // Remove any other actions using this same shortcut
            removeConflictingShortcuts(for: shortcut, excluding: action)
            shortcuts[action] = shortcut
            
            #if DEBUG
            print("[DEBUG][Settings] Updated shortcut for \(action.rawValue): \(shortcut.displayString)")
            #endif
        } else {
            shortcuts[action] = nil
            #if DEBUG
            print("[DEBUG][Settings] Cleared shortcut for \(action.rawValue)")
            #endif
        }
        
        // Track shortcut change safely
        trackShortcutChange(action: action, oldShortcut: oldShortcut, newShortcut: shortcuts[action])
    }
    
    private func removeConflictingShortcuts(for newShortcut: KeyboardShortcut, excluding action: ShortcutAction) {
        // Safely remove conflicting shortcuts
        var conflictingActions: [ShortcutAction] = []
        
        for (existingAction, existingShortcut) in shortcuts {
            // Skip if it's the same action
            guard existingAction != action else {
                continue
            }
            
            // Check if shortcuts match
            if existingShortcut.keyCode == newShortcut.keyCode && 
               existingShortcut.modifierFlags == newShortcut.modifierFlags {
                conflictingActions.append(existingAction)
            }
        }
        
        // Remove conflicts
        for conflictingAction in conflictingActions {
            #if DEBUG
            print("[DEBUG][Settings] Removing conflicting shortcut from \(conflictingAction.rawValue)")
            #endif
            shortcuts[conflictingAction] = nil
        }
    }
    
    private func trackShortcutChange(action: ShortcutAction, oldShortcut: KeyboardShortcut?, newShortcut: KeyboardShortcut?) {
        // Only track if shortcut actually changed
        let keyCodeChanged = oldShortcut?.keyCode != newShortcut?.keyCode
        let modifiersChanged = oldShortcut?.modifierFlags != newShortcut?.modifierFlags
        
        if keyCodeChanged || modifiersChanged {
            trackAnalytics(.shortcutChanged, properties: [
                "action": action.rawValue,
                "has_shortcut": newShortcut != nil
            ])
        }
    }
    
    func getShortcut(for action: ShortcutAction) -> KeyboardShortcut? {
        return shortcuts[action]
    }
    
    func resetAllSettings() {
        // Reset all settings to defaults
        themeMode = ThemeMode.auto.rawValue
        defaultPosition = DefaultPosition.center.rawValue
        savedWindowPosition = nil
        enableAnimations = true
        showMenuBarIcon = true
        showQuickSlotsInMenuBar = true
        menuBarQuickSlotCount = 5
        debugMode = false
        showTechnicalInfo = false
        resetShortcutsToDefault()
        resetWindowPosition()
    }
    
    func incrementLaunchCount() {
        launchCount += 1
    }
}