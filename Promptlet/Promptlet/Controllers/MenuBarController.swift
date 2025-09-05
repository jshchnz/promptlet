//
//  MenuBarController.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import Cocoa
import SwiftUI
import Combine

@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var delegate: MenuBarDelegate?
    private weak var promptStore: PromptStore?
    private weak var appSettings: AppSettings?
    private var cancellables = Set<AnyCancellable>()
    
    init(delegate: MenuBarDelegate, promptStore: PromptStore, appSettings: AppSettings) {
        self.delegate = delegate
        self.promptStore = promptStore
        self.appSettings = appSettings
        super.init()
        setupMenuBar()
        observeSettings()
    }
    
    private func observeSettings() {
        // Observe changes to showMenuBarIcon setting
        guard appSettings != nil else { return }
        
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.updateMenuBarVisibility()
                self?.updateMenuBarIcon()
                self?.createMenu() // Refresh menu when settings change
            }
        }
        
        // Observe shortcut changes to update menu
        NotificationCenter.default.addObserver(
            forName: Notification.Name("shortcutsChanged"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.createMenu()
            }
        }
        
        // Observe prompt store changes to update menu when quick slots change
        promptStore?.$prompts.sink { [weak self] _ in
            Task { @MainActor in
                self?.createMenu()
            }
        }.store(in: &cancellables)
    }
    
    private func updateMenuBarVisibility() {
        guard let settings = appSettings else { return }
        
        if settings.showMenuBarIcon {
            if statusItem == nil {
                setupMenuBar()
            }
        } else {
            if let statusItem = statusItem {
                NSStatusBar.system.removeStatusItem(statusItem)
                self.statusItem = nil
            }
        }
    }
    
    private func updateMenuBarIcon() {
        guard let settings = appSettings,
              settings.showMenuBarIcon,
              let button = statusItem?.button else { return }
        
        let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
        let selectedIconName = settings.selectedMenuBarIcon.systemImageName
        
        if let image = NSImage(systemSymbolName: selectedIconName, accessibilityDescription: "Promptlet") {
            button.image = image.withSymbolConfiguration(config)
            button.title = "" // Clear any fallback title
        } else if let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Promptlet") {
            // Fallback to default icon
            button.image = image.withSymbolConfiguration(config)
            button.title = ""
        } else if let image = NSImage(systemSymbolName: "command", accessibilityDescription: "Promptlet") {
            // Second fallback to command symbol
            button.image = image.withSymbolConfiguration(config)
            button.title = ""
        } else {
            // Last fallback to text
            button.image = nil
            button.title = "⌘."
        }
    }
    
    private func setupMenuBar() {
        guard appSettings?.showMenuBarIcon == true else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            let selectedIconName = appSettings?.selectedMenuBarIcon.systemImageName ?? "text.quote"
            
            if let image = NSImage(systemSymbolName: selectedIconName, accessibilityDescription: "Promptlet") {
                button.image = image.withSymbolConfiguration(config)
            } else if let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Promptlet") {
                // Fallback to default icon
                button.image = image.withSymbolConfiguration(config)
            } else if let image = NSImage(systemSymbolName: "command", accessibilityDescription: "Promptlet") {
                // Second fallback to command symbol
                button.image = image.withSymbolConfiguration(config)
            } else {
                // Last fallback to text
                button.title = "⌘."
            }
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        
        createMenu()
        
        logSuccess(.ui, "Menu bar setup complete")
    }
    
    func createMenu() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        // Add quick slot items if enabled
        if let settings = appSettings,
           let store = promptStore,
           settings.showQuickSlotsInMenuBar {
            
            let quickSlots = store.quickSlotPrompts
            let slotsToShow = min(settings.menuBarQuickSlotCount, 5)
            var addedQuickSlots = false
            
            for slot in 1...slotsToShow {
                if let prompt = quickSlots[slot] {
                    // Get the actual configured shortcut for this slot
                    let shortcutAction = getShortcutAction(for: slot)
                    let configuredShortcut = shortcutAction != nil ? settings.getShortcut(for: shortcutAction!) : nil
                    
                    let item = NSMenuItem(
                        title: prompt.title,
                        action: #selector(insertQuickSlotPrompt(_:)),
                        keyEquivalent: ""
                    )
                    
                    // Set the actual shortcut if configured
                    if let shortcut = configuredShortcut {
                        item.keyEquivalent = keyEquivalentString(for: shortcut.keyCode)
                        item.keyEquivalentModifierMask = nsEventModifierFlags(from: shortcut.modifierFlags)
                    }
                    
                    item.representedObject = prompt.id
                    item.target = self
                    menu.addItem(item)
                    addedQuickSlots = true
                }
            }
            
            if addedQuickSlots {
                menu.addItem(NSMenuItem.separator())
            }
        }
        
        // Get the actual keyboard shortcut from settings
        let shortcutDisplay = appSettings?.getShortcut(for: .showPalette)?.displayString ?? "⌘⌥."
        let openItem = NSMenuItem(title: "Open Palette (\(shortcutDisplay))", action: #selector(showPalette), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        
        let quickAddItem = NSMenuItem(title: "Quick Add from Clipboard", action: #selector(quickAddFromClipboard), keyEquivalent: "n")
        quickAddItem.target = self
        menu.addItem(quickAddItem)
        menu.addItem(NSMenuItem.separator())
        
        if let store = promptStore {
            let recentSubmenu = NSMenu()
            for prompt in store.recentPrompts.prefix(5) {
                let item = NSMenuItem(title: prompt.title, action: #selector(insertRecentPrompt(_:)), keyEquivalent: "")
                item.representedObject = prompt.id
                item.target = self
                recentSubmenu.addItem(item)
            }
            
            let recentItem = NSMenuItem(title: "Recent Prompts", action: nil, keyEquivalent: "")
            recentItem.submenu = recentSubmenu
            menu.addItem(recentItem)
        }
        
        menu.addItem(NSMenuItem.separator())
        
        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit Promptlet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        
        statusItem.menu = menu
    }
    
    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            delegate?.menuBarShowPalette()
        }
    }
    
    @objc private func showPalette() {
        delegate?.menuBarShowPalette()
    }
    
    @objc private func quickAddFromClipboard() {
        delegate?.menuBarQuickAddFromClipboard()
    }
    
    @objc private func insertRecentPrompt(_ sender: NSMenuItem) {
        guard let promptId = sender.representedObject as? UUID else { return }
        delegate?.menuBarInsertRecentPrompt(promptId)
    }
    
    @objc private func insertQuickSlotPrompt(_ sender: NSMenuItem) {
        guard let promptId = sender.representedObject as? UUID else { return }
        delegate?.menuBarInsertQuickSlotPrompt(promptId)
    }
    
    @objc private func openSettings() {
        // Delegate to AppDelegate to handle settings
        delegate?.menuBarOpenSettings()
    }
    
    // MARK: - Helper Methods
    
    private func getShortcutAction(for slot: Int) -> ShortcutAction? {
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
        default: return nil
        }
    }
    
    private func keyEquivalentString(for keyCode: UInt16) -> String {
        switch keyCode {
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 23: return "5"
        case 22: return "6"
        case 26: return "7"
        case 28: return "8"
        case 25: return "9"
        case 29: return "0"
        case 12: return "q"
        case 13: return "w"
        case 14: return "e"
        case 15: return "r"
        case 17: return "t"
        case 16: return "y"
        case 32: return "u"
        case 34: return "i"
        case 31: return "o"
        case 35: return "p"
        case 0: return "a"
        case 1: return "s"
        case 2: return "d"
        case 3: return "f"
        case 5: return "g"
        case 4: return "h"
        case 38: return "j"
        case 40: return "k"
        case 37: return "l"
        case 6: return "z"
        case 7: return "x"
        case 8: return "c"
        case 9: return "v"
        case 11: return "b"
        case 45: return "n"
        case 46: return "m"
        case 47: return "."
        case 44: return ","
        case 36: return "\r" // Return
        case 53: return "\u{1b}" // Escape
        case 49: return " " // Space
        default: return ""
        }
    }
    
    private func nsEventModifierFlags(from modifierFlags: UInt) -> NSEvent.ModifierFlags {
        return NSEvent.ModifierFlags(rawValue: modifierFlags)
    }
    
    func showInsertedFeedback() {
        guard let button = statusItem?.button else { return }
        
        let originalTitle = button.title
        let originalImage = button.image
        
        button.title = "✓"
        button.image = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            button.title = originalTitle
            button.image = originalImage
        }
    }
    
    func showResetFeedback() {
        guard let button = statusItem?.button else { return }
        
        let originalTitle = button.title
        let originalImage = button.image
        
        button.title = "↻"
        button.image = nil
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            button.title = originalTitle
            button.image = originalImage
        }
    }
}

@MainActor
protocol MenuBarDelegate: AnyObject {
    func menuBarShowPalette()
    func menuBarQuickAddFromClipboard()
    func menuBarInsertRecentPrompt(_ promptId: UUID)
    func menuBarInsertQuickSlotPrompt(_ promptId: UUID)
    func menuBarOpenSettings()
}