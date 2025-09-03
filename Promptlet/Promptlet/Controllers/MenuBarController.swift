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
    
    private func setupMenuBar() {
        guard appSettings?.showMenuBarIcon == true else { return }
        
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            // Good SF Symbol options for a prompt/snippet manager:
            // "text.quote" - quotation marks, good for text snippets
            // "command" - clean command key symbol
            // "doc.text" - document with text
            // "rectangle.and.text.magnifyingglass" - search text
            // "text.bubble" - speech/text bubble
            let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
            if let image = NSImage(systemSymbolName: "text.quote", accessibilityDescription: "Promptlet") {
                button.image = image.withSymbolConfiguration(config)
            } else if let image = NSImage(systemSymbolName: "command", accessibilityDescription: "Promptlet") {
                // Fallback to command symbol
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
                    let shortcutKey = String(slot)
                    let item = NSMenuItem(
                        title: prompt.title,
                        action: #selector(insertQuickSlotPrompt(_:)),
                        keyEquivalent: shortcutKey
                    )
                    item.keyEquivalentModifierMask = [.command]
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
        
        let resetPositionItem = NSMenuItem(title: "Reset Window Position", action: #selector(resetWindowPosition), keyEquivalent: "")
        resetPositionItem.target = self
        menu.addItem(resetPositionItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Diagnostics submenu
        let diagnosticsSubmenu = NSMenu()
        
        let shortcutStatusItem = NSMenuItem(title: "Shortcut Status", action: #selector(showShortcutStatus), keyEquivalent: "")
        shortcutStatusItem.target = self
        diagnosticsSubmenu.addItem(shortcutStatusItem)
        
        let permissionStatusItem = NSMenuItem(title: "Permission Status", action: #selector(showPermissionStatus), keyEquivalent: "")
        permissionStatusItem.target = self
        diagnosticsSubmenu.addItem(permissionStatusItem)
        
        let resetShortcutsItem = NSMenuItem(title: "Reset Shortcuts", action: #selector(resetShortcuts), keyEquivalent: "")
        resetShortcutsItem.target = self
        diagnosticsSubmenu.addItem(resetShortcutsItem)
        
        diagnosticsSubmenu.addItem(NSMenuItem.separator())
        
        let showLogsItem = NSMenuItem(title: "Show Debug Logs", action: #selector(showDebugLogs), keyEquivalent: "")
        showLogsItem.target = self
        diagnosticsSubmenu.addItem(showLogsItem)
        
        let diagnosticsItem = NSMenuItem(title: "Diagnostics", action: nil, keyEquivalent: "")
        diagnosticsItem.submenu = diagnosticsSubmenu
        menu.addItem(diagnosticsItem)
        
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
    
    @objc private func resetWindowPosition() {
        delegate?.menuBarResetWindowPosition()
    }
    
    // MARK: - Diagnostic Actions
    
    @objc private func showShortcutStatus() {
        delegate?.menuBarShowShortcutStatus()
    }
    
    @objc private func showPermissionStatus() {
        delegate?.menuBarShowPermissionStatus()
    }
    
    @objc private func resetShortcuts() {
        delegate?.menuBarResetShortcuts()
    }
    
    @objc private func showDebugLogs() {
        delegate?.menuBarShowDebugLogs()
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
    func menuBarResetWindowPosition()
    
    // Diagnostic methods
    func menuBarShowShortcutStatus()
    func menuBarShowPermissionStatus()
    func menuBarResetShortcuts()
    func menuBarShowDebugLogs()
}