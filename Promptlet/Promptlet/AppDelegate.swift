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
    var promptStore: PromptStore!
    var paletteController: PaletteController!
    let appSettings = AppSettings()  // Initialize immediately for Settings scene
    var previousApp: NSRunningApplication?
    
    private var menuBarController: MenuBarController!
    private var keyboardController: KeyboardController!
    private var windowController: WindowController!
    private var settingsWindow: NSWindow?
    private var promptEditorWindow: NSWindow?
    private var onboardingWindow: OnboardingWindow?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        print("[AppDelegate] Application launched")
        logInfo("AppDelegate", "Application launched")
        
        // Initialize core components immediately
        promptStore = PromptStore()
        paletteController = PaletteController(store: promptStore)
        appSettings.applyTheme()  // Apply theme after app launches
        appSettings.incrementLaunchCount()
        logInfo("AppDelegate", "Core components initialized")
        
        // Initialize controllers
        menuBarController = MenuBarController(delegate: self, promptStore: promptStore, appSettings: appSettings)
        keyboardController = KeyboardController(delegate: self, appSettings: appSettings)
        windowController = WindowController(delegate: self)
        logInfo("AppDelegate", "Controllers initialized")
        
        // Check if onboarding is needed
        if !appSettings.hasCompletedOnboarding {
            print("[AppDelegate] Showing onboarding")
            logInfo("AppDelegate", "Showing onboarding - first launch detected")
            showOnboardingWindow()
        } else {
            // Only request permissions and setup if onboarding is complete
            logInfo("AppDelegate", "Onboarding already completed, setting up permissions")
            requestAccessibilityPermissions()
            keyboardController.setupGlobalHotkey()
        }
        
        // Listen for shortcut changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(shortcutsDidChange),
            name: .shortcutsChanged,
            object: nil
        )
        
        NSApp.setActivationPolicy(.accessory)
        
        // Listen for test notifications from onboarding
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTestShowPalette),
            name: Notification.Name("ShowPaletteTest"),
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTestHidePalette),
            name: Notification.Name("HidePaletteTest"),
            object: nil
        )
        
        print("[AppDelegate] Setup complete")
        logSuccess("AppDelegate", "Application setup completed successfully")
    }
    
    private func requestAccessibilityPermissions() {
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let trusted = AXIsProcessTrustedWithOptions(options)
        
        if trusted {
            print("[AppDelegate] Accessibility permissions granted")
            logSuccess("Permissions", "Accessibility permissions granted")
        } else {
            print("[AppDelegate] Accessibility permissions not granted - requesting...")
            logWarning("Permissions", "Accessibility permissions not granted - requesting user approval")
        }
    }
    
    @objc func showPalette() {
        // Toggle palette visibility - only hide if it's actually frontmost
        if windowController.isPaletteFrontmost() {
            print("[AppDelegate] Hiding palette (toggle)")
            hidePalette()
            return
        }
        
        print("[AppDelegate] Showing palette")
        
        // Save the currently active app before showing palette
        previousApp = NSWorkspace.shared.frontmostApplication
        print("[AppDelegate] Saved previous app: \(previousApp?.localizedName ?? "none")")
        
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
        let paletteView = SimplePaletteView(
            store: promptStore,
            controller: paletteController,
            appSettings: appSettings,
            onInsert: { [weak self] prompt in
                self?.insertPrompt(prompt)
            },
            onDismiss: { [weak self] in
                self?.hidePalette()
            }
        )
        
        windowController.createPaletteWindow(view: paletteView, appSettings: appSettings)
    }
    
    func hidePalette() {
        print("[AppDelegate] Hiding palette")
        windowController.hidePalette()
        keyboardController.stopPaletteKeyboardMonitoring()
    }
    
    private func insertPrompt(_ prompt: Prompt) {
        let content = prompt.renderedContent(with: [:])
        
        // Hide palette first to release focus
        hidePalette()
        
        // Save current clipboard
        let previousClipboard = NSPasteboard.general.string(forType: .string)
        
        // Set prompt content to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // Restore focus to the original app
        if let app = previousApp {
            print("[AppDelegate] Restoring focus to: \(app.localizedName ?? "unknown")")
            app.activate()
            
            // Wait for focus to restore, then paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.keyboardController.simulatePaste()
                
                // Restore previous clipboard after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let previous = previousClipboard {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(previous, forType: .string)
                    }
                }
                
                print("[AppDelegate] Inserted prompt: \(prompt.title)")
                logSuccess("TextInsertion", "Successfully inserted prompt: \(prompt.title)")
            }
        }
        
        promptStore.recordUsage(for: prompt.id)
        menuBarController.showInsertedFeedback()
    }
    
    private func showPromptEditor(for prompt: Prompt) {
        print("[AppDelegate] Showing prompt editor for: \(prompt.title)")
        
        // Hide palette if visible
        if windowController.isPaletteVisible() {
            hidePalette()
        }
        
        // Create prompt editor view
        let editorView = PromptEditorView(
            prompt: prompt,
            onSave: { [weak self] updatedPrompt in
                self?.handlePromptSave(updatedPrompt)
            },
            onCancel: { [weak self] in
                self?.closePromptEditor()
            }
        )
        
        let hostingView = NSHostingView(rootView: editorView)
        
        // Create or reuse window
        if promptEditorWindow == nil {
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Edit Prompt"
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.center()
            promptEditorWindow = window
        }
        
        promptEditorWindow?.contentView = hostingView
        promptEditorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    private func handlePromptSave(_ prompt: Prompt) {
        // Update the prompt in the store
        promptStore.updatePrompt(prompt)
        print("[AppDelegate] Updated prompt: \(prompt.title)")
        closePromptEditor()
    }
    
    private func closePromptEditor() {
        promptEditorWindow?.close()
        promptEditorWindow = nil
    }
    
    @objc private func shortcutsDidChange() {
        print("[AppDelegate] Keyboard shortcuts changed, reloading...")
        keyboardController.reloadShortcuts()
    }
    
    private func showOnboardingWindow() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindow()
        }
        
        let onboardingView = ModernOnboardingView(
            settings: appSettings,
            onComplete: { [weak self] in
                self?.onboardingCompleted()
            }
        )
        
        onboardingWindow?.showOnboarding(with: onboardingView)
    }
    
    private func onboardingCompleted() {
        print("[AppDelegate] Onboarding completed")
        onboardingWindow?.close()
        onboardingWindow = nil
        
        // Now setup permissions and keyboard shortcuts
        requestAccessibilityPermissions()
        keyboardController.setupGlobalHotkey()
        
        // Show the palette for the first time
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showPalette()
        }
    }
    
    @objc private func handleTestShowPalette() {
        showPalette()
    }
    
    @objc private func handleTestHidePalette() {
        hidePalette()
    }
}

// MARK: - MenuBarDelegate

extension AppDelegate: MenuBarDelegate {
    func menuBarShowPalette() {
        showPalette()
    }
    
    func menuBarQuickAddFromClipboard() {
        print("[AppDelegate] Quick add from clipboard")
        
        guard let content = NSPasteboard.general.string(forType: .string) else {
            print("[AppDelegate] No text in clipboard")
            return
        }
        
        let prompt = Prompt(
            title: "New Prompt",
            content: content,
            tags: [],
            defaultEnhancement: Enhancement()
        )
        
        promptStore.addPrompt(prompt)
        showPromptEditor(for: prompt)
    }
    
    func menuBarInsertRecentPrompt(_ promptId: UUID) {
        guard let prompt = promptStore.prompts.first(where: { $0.id == promptId }) else {
            return
        }
        
        print("[AppDelegate] Inserting recent prompt: \(prompt.title)")
        insertPrompt(prompt)
    }
    
    func menuBarOpenSettings() {
        print("[AppDelegate] Opening settings")
        
        // Create and show settings window directly
        if settingsWindow == nil {
            let settingsView = SettingsView(settings: appSettings)
            let hostingView = NSHostingView(rootView: settingsView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 680, height: 420),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "Promptlet Settings"
            window.contentView = hostingView
            window.center()
            window.isReleasedWhenClosed = false
            
            settingsWindow = window
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func menuBarResetWindowPosition() {
        appSettings.resetWindowPosition()
        menuBarController.showResetFeedback()
        print("[AppDelegate] Reset window position")
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
        print("[AppDelegate] New prompt requested via Cmd+N")
        
        // Get clipboard content if available
        let content = NSPasteboard.general.string(forType: .string) ?? ""
        
        let prompt = Prompt(
            title: "New Prompt",
            content: content,
            tags: [],
            defaultEnhancement: Enhancement()
        )
        
        promptStore.addPrompt(prompt)
        showPromptEditor(for: prompt)
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