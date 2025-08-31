//
//  MenuBarController.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import Cocoa
import SwiftUI

@MainActor
class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private weak var delegate: MenuBarDelegate?
    private weak var promptStore: PromptStore?
    private weak var appSettings: AppSettings?
    
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
        guard let settings = appSettings else { return }
        
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuBarVisibility()
        }
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
        
        print("[MenuBarController] Menu bar setup complete")
    }
    
    func createMenu() {
        guard let statusItem = statusItem else { return }
        
        let menu = NSMenu()
        
        let openItem = NSMenuItem(title: "Open Palette (⌘. or ⌃⌘Space)", action: #selector(showPalette), keyEquivalent: ".")
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
    
    @objc private func openSettings() {
        // Delegate to AppDelegate to handle settings
        delegate?.menuBarOpenSettings()
    }
    
    @objc private func resetWindowPosition() {
        delegate?.menuBarResetWindowPosition()
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
    func menuBarOpenSettings()
    func menuBarResetWindowPosition()
}