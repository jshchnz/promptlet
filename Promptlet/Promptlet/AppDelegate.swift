//
//  AppDelegate.swift
//  Promptlet
//
//  Created by Josh Cohenzadeh on 8/29/25.
//

import Cocoa
import SwiftUI

extension Notification.Name {
    static let shortcutsChanged = Notification.Name("shortcutsChanged")
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    // MARK: - Core Data & Controllers
    var promptStore: PromptStore = PromptStore()
    var paletteController: PaletteController!
    let appSettings = AppSettings()
    
    // MARK: - Controllers
    private var menuBarController: MenuBarController!
    private var keyboardController: KeyboardController!
    private var windowController: WindowController!
    
    // MARK: - Services
    private var textInsertionService: TextInsertionService!
    private var windowManagementService: WindowManagementService!
    private var onboardingService: OnboardingService!
    private var permissionService: PermissionManager!
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logInfo(.app, "Application launched")
        
        // Initialize core components
        paletteController = PaletteController(store: promptStore)
        appSettings.applyTheme()
        appSettings.incrementLaunchCount()
        logInfo(.app, "Core components initialized")
        
        // Initialize services
        textInsertionService = TextInsertionService()
        windowManagementService = WindowManagementService()
        onboardingService = OnboardingService(settings: appSettings)
        permissionService = PermissionManager.shared
        logInfo(.app, "Services initialized")
        
        // Initialize controllers
        menuBarController = MenuBarController(delegate: self, promptStore: promptStore, appSettings: appSettings)
        keyboardController = KeyboardController(delegate: self, appSettings: appSettings)
        windowController = WindowController(delegate: self)
        logInfo(.app, "Controllers initialized")
        
        // Handle onboarding and permissions
        if onboardingService.isOnboardingNeeded {
            onboardingService.showOnboarding { [weak self] in
                self?.setupPostOnboarding()
            }
        } else {
            logInfo(.onboarding, "Onboarding already completed, setting up permissions")
            setupPostOnboarding()
        }
        
        // Listen for shortcut changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutsDidChange),
            name: .shortcutsChanged,
            object: nil
        )
        
        NSApp.setActivationPolicy(.accessory)
        
        // Setup onboarding test notifications
        onboardingService.handleTestNotifications()
        setupTestNotificationHandlers()
        
        logSuccess(.app, "Application setup completed successfully")
    }
    
    private func setupPostOnboarding() {
        permissionService.requestAccessibilityPermissions()
        keyboardController.setupGlobalHotkey()
        
        // Show the palette for the first time after onboarding
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showPalette()
        }
    }
    
    private func setupTestNotificationHandlers() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TestShowPalette"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.showPalette()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("TestHidePalette"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.hidePalette()
            }
        }
    }
    
    @objc func showPalette() {
        // Toggle palette visibility - only hide if it's actually frontmost
        if windowController.isPaletteFrontmost() {
            logDebug(.ui, "Hiding palette (toggle)")
            hidePalette()
            return
        }
        
        logDebug(.ui, "Showing palette")
        
        // Save the currently active app before showing palette
        let currentApp = NSWorkspace.shared.frontmostApplication
        textInsertionService.setPreviousApp(currentApp)
        
        if !windowController.isPaletteVisible() {
            createPaletteWindow()
        }
        
        // Reset controller and clear search
        paletteController.reset()
        promptStore.searchText = ""
        
        windowController.showPalette(appSettings: appSettings)
        keyboardController.startPaletteKeyboardMonitoring()
    }
    
    private func createPaletteWindow() {
        let paletteView = PaletteView(
            store: promptStore,
            controller: paletteController,
            appSettings: appSettings,
            onInsert: { [weak self] prompt in
                self?.insertPrompt(prompt)
            },
            onDismiss: { [weak self] in
                self?.hidePalette()
            },
            onNewPrompt: { [weak self] in
                self?.keyboardNewPrompt()
            }
        )
        
        windowController.createPaletteWindow(view: paletteView, appSettings: appSettings)
    }
    
    func hidePalette() {
        logDebug(.ui, "Hiding palette")
        windowController.hidePalette(animated: appSettings.enableAnimations)
        keyboardController.stopPaletteKeyboardMonitoring()
    }
    
    private func insertPrompt(_ prompt: Prompt) {
        // Hide palette first to release focus
        hidePalette()
        
        // Use service to handle text insertion
        textInsertionService.insertPrompt(prompt) { [weak self] in
            // Record usage and show feedback
            self?.promptStore.recordUsage(for: prompt.id)
            self?.menuBarController.showInsertedFeedback()
        }
    }
    
    private func showPromptEditor(for prompt: Prompt, isNew: Bool = false) {
        // Hide palette if visible
        if windowController.isPaletteVisible() {
            hidePalette()
        }
        
        logInfo(.prompt, isNew ? "Opening editor for new prompt" : "Opening editor for existing prompt: \(prompt.title)")
        
        windowManagementService.showPromptEditor(
            for: prompt,
            onSave: { [weak self] updatedPrompt in
                if isNew {
                    self?.promptStore.addPrompt(updatedPrompt)
                    logSuccess(.prompt, "New prompt created and saved: \(updatedPrompt.title)")
                } else {
                    self?.promptStore.updatePrompt(updatedPrompt)
                    logInfo(.prompt, "Existing prompt updated: \(updatedPrompt.title)")
                }
                self?.windowManagementService.closePromptEditor()
            },
            onCancel: {
                if isNew {
                    logInfo(.prompt, "New prompt creation cancelled - no prompt saved")
                } else {
                    logInfo(.prompt, "Edit cancelled for prompt: \(prompt.title)")
                }
            }
        )
    }
    
    @objc private func shortcutsDidChange() {
        logInfo(.keyboard, "Keyboard shortcuts changed, reloading...")
        keyboardController.reloadShortcuts()
        menuBarController.createMenu()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        logInfo(.app, "Application terminating, cleaning up resources")
        keyboardController.cleanup()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - MenuBarDelegate

extension AppDelegate: MenuBarDelegate {
    func menuBarShowPalette() {
        showPalette()
    }
    
    func menuBarQuickAddFromClipboard() {
        logInfo(.prompt, "Quick add from clipboard initiated")
        
        guard let content = NSPasteboard.general.string(forType: .string) else {
            logWarning(.prompt, "No text in clipboard for quick add")
            return
        }
        
        let prompt = Prompt(
            title: "New Prompt",
            content: content,
            tags: [],
            defaultEnhancement: Enhancement()
        )
        
        // Don't add to store yet - wait for user to save
        showPromptEditor(for: prompt, isNew: true)
    }
    
    func menuBarInsertRecentPrompt(_ promptId: UUID) {
        guard let prompt = promptStore.prompts.first(where: { $0.id == promptId }) else {
            return
        }
        
        logInfo(.prompt, "Inserting recent prompt: \(prompt.title)")
        insertPrompt(prompt)
    }
    
    func menuBarInsertQuickSlotPrompt(_ promptId: UUID) {
        guard let prompt = promptStore.prompts.first(where: { $0.id == promptId }) else {
            return
        }
        
        logInfo(.prompt, "Inserting quick slot prompt from menu: \(prompt.title)")
        insertPrompt(prompt)
    }
    
    func menuBarOpenSettings() {
        windowManagementService.showSettingsWindow(with: appSettings, promptStore: promptStore)
    }
    
    func menuBarResetWindowPosition() {
        appSettings.resetWindowPosition()
        menuBarController.showResetFeedback()
        logInfo(.window, "Reset window position")
    }
}

// MARK: - KeyboardControllerDelegate

extension AppDelegate: KeyboardControllerDelegate {
    func keyboardShowPalette() {
        showPalette()
    }
    
    func keyboardHidePalette() {
        hidePalette()
    }
    
    func keyboardNavigateUp() {
        paletteController.navigateUp()
    }
    
    func keyboardNavigateDown() {
        paletteController.navigateDown()
    }
    
    func keyboardQuickSlot(_ slot: Int) {
        if let prompt = promptStore.quickSlotPrompts[slot] {
            insertPrompt(prompt)
        }
    }
    
    func keyboardNewPrompt() {
        logInfo(.keyboard, "New prompt creation initiated")
        
        // Get clipboard content if available
        let content = NSPasteboard.general.string(forType: .string) ?? ""
        
        let prompt = Prompt(
            title: "New Prompt",
            content: content,
            tags: [],
            defaultEnhancement: Enhancement()
        )
        
        // Don't add to store yet - wait for user to save
        showPromptEditor(for: prompt, isNew: true)
    }
    
    func isPaletteVisible() -> Bool {
        return windowController.isPaletteVisible()
    }
}

// MARK: - WindowControllerDelegate

extension AppDelegate: WindowControllerDelegate {
    func windowDidMove() {
        // Could refresh menu or perform other actions if needed
    }
}