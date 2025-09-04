//
//  ServiceCoordinator.swift
//  Promptlet
//
//  Coordinates interactions between different services and components
//

import Cocoa
import SwiftUI
import Combine

@MainActor
class ServiceCoordinator: ObservableObject {
    
    // Core Services
    private(set) var promptStore: PromptStore
    private(set) var appSettings: AppSettings
    
    // Controllers
    private var paletteController: PaletteController?
    private var menuBarController: MenuBarController?
    private var keyboardController: KeyboardController?
    private var windowController: WindowController?
    
    // Services
    private var textInsertionService: TextInsertionService?
    private var windowManagementService: WindowManagementService?
    private var onboardingService: OnboardingService?
    private var permissionService: PermissionManager?
    private var appSetupService: AppSetupService?
    
    // Service integration
    private var cancellables = Set<AnyCancellable>()
    
    init(promptStore: PromptStore, appSettings: AppSettings) {
        self.promptStore = promptStore
        self.appSettings = appSettings
        logInfo(.app, "ServiceCoordinator initialized")
    }
    
    // MARK: - Service Registration
    
    func registerControllers(
        paletteController: PaletteController,
        menuBarController: MenuBarController,
        keyboardController: KeyboardController,
        windowController: WindowController
    ) {
        self.paletteController = paletteController
        self.menuBarController = menuBarController
        self.keyboardController = keyboardController
        self.windowController = windowController
        
        setupControllerIntegration()
        logInfo(.app, "Controllers registered with ServiceCoordinator")
    }
    
    func registerServices(
        textInsertionService: TextInsertionService,
        windowManagementService: WindowManagementService,
        onboardingService: OnboardingService,
        permissionService: PermissionManager,
        appSetupService: AppSetupService
    ) {
        self.textInsertionService = textInsertionService
        self.windowManagementService = windowManagementService
        self.onboardingService = onboardingService
        self.permissionService = permissionService
        self.appSetupService = appSetupService
        
        setupServiceIntegration()
        logInfo(.app, "Services registered with ServiceCoordinator")
    }
    
    // MARK: - Integration Setup
    
    private func setupControllerIntegration() {
        // Setup keyboard shortcut change notifications
        NotificationCenter.default.addObserver(
            forName: NotificationNames.shortcutsChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleShortcutChanges()
            }
        }
    }
    
    private func setupServiceIntegration() {
        // Setup permission monitoring integration
        setupPermissionIntegration()
        
        // Setup prompt store change monitoring
        setupPromptStoreIntegration()
    }
    
    private func setupPermissionIntegration() {
        guard let permissionManager = permissionService,
              let keyboardController = keyboardController else { return }
        
        // Add callback to re-register keyboard monitors when accessibility permission changes
        permissionManager.addPermissionChangeCallback { [weak keyboardController] hasPermission in
            logInfo(.permission, "Permission change callback triggered: \(hasPermission)")
            if hasPermission {
                logInfo(.keyboard, "Accessibility permission restored, re-registering monitors")
                keyboardController?.forceReregisterMonitors()
            } else {
                logWarning(.keyboard, "Accessibility permission lost, monitors may not work")
            }
        }
        
        // Start monitoring permissions
        permissionManager.startMonitoringPermissions()
        
        logInfo(.app, "Permission integration setup completed")
    }
    
    private func setupPromptStoreIntegration() {
        // Monitor prompt changes to update menu bar
        promptStore.$prompts
            .debounce(for: .seconds(Timing.debounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.handlePromptStoreChanges()
            }
            .store(in: &cancellables)
    }
    
    // MARK: - Event Handling
    
    private func handleShortcutChanges() {
        logInfo(.keyboard, "Keyboard shortcuts changed, updating components")
        keyboardController?.reloadShortcuts()
        menuBarController?.createMenu()
    }
    
    private func handlePromptStoreChanges() {
        logDebug(.prompt, "Prompt store changed, updating dependent components")
        menuBarController?.createMenu()
    }
    
    // MARK: - Palette Management
    
    func showPalette() {
        guard let windowController = windowController,
              let paletteController = paletteController,
              let textInsertionService = textInsertionService else { return }
        
        logDebug(.ui, "Showing palette")
        
        // Toggle palette visibility - only hide if it's actually frontmost
        if windowController.isPaletteFrontmost() {
            logDebug(.ui, "Hiding palette (toggle)")
            hidePalette()
            return
        }
        
        // Save the currently active app before showing palette
        let currentApp = NSWorkspace.shared.frontmostApplication
        textInsertionService.setPreviousApp(currentApp)
        
        // Create palette window if needed
        if !windowController.isPaletteVisible() {
            createPaletteWindow()
        }
        
        // Reset controller and clear search
        paletteController.reset()
        promptStore.searchText = ""
        
        // Show the palette
        windowController.showPalette(appSettings: appSettings)
        keyboardController?.startPaletteKeyboardMonitoring()
    }
    
    func hidePalette() {
        logDebug(.ui, "Hiding palette")
        windowController?.hidePalette(animated: appSettings.enableAnimations)
        keyboardController?.stopPaletteKeyboardMonitoring()
    }
    
    private func createPaletteWindow() {
        guard let windowController = windowController,
              let paletteController = paletteController else { return }
        
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
                self?.createNewPrompt()
            }
        )
        
        windowController.createPaletteWindow(view: paletteView, appSettings: appSettings)
    }
    
    // MARK: - Prompt Actions
    
    func insertPrompt(_ prompt: Prompt) {
        guard let textInsertionService = textInsertionService,
              let menuBarController = menuBarController else { return }
        
        // Hide palette first to release focus
        hidePalette()
        
        // Use service to handle text insertion
        textInsertionService.insertPrompt(prompt) { [weak self] in
            // Record usage and show feedback
            self?.promptStore.recordUsage(for: prompt.id)
            menuBarController.showInsertedFeedback()
        }
    }
    
    func insertPromptDirectly(_ prompt: Prompt) {
        guard let textInsertionService = textInsertionService,
              let menuBarController = menuBarController else { return }
        
        textInsertionService.insertPromptDirectly(prompt) { [weak self] in
            self?.promptStore.recordUsage(for: prompt.id)
            menuBarController.showInsertedFeedback()
        }
    }
    
    func createNewPrompt() {
        guard windowManagementService != nil else { return }
        
        logInfo(.keyboard, "New prompt creation initiated")
        
        // Get clipboard content if available
        let content = NSPasteboard.general.string(forType: .string) ?? ""
        
        let prompt = Prompt(
            title: TextConstants.defaultPromptTitle,
            content: content,
            tags: [],
            defaultEnhancement: Enhancement()
        )
        
        showPromptEditor(for: prompt, isNew: true)
    }
    
    func showPromptEditor(for prompt: Prompt, isNew: Bool = false) {
        guard let windowManagementService = windowManagementService else { return }
        
        // Hide palette if visible
        if windowController?.isPaletteVisible() == true {
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
                self?.windowManagementService?.closePromptEditor()
            },
            onCancel: {
                if isNew {
                    logInfo(.prompt, "New prompt creation cancelled")
                } else {
                    logInfo(.prompt, "Edit cancelled for prompt: \(prompt.title)")
                }
            }
        )
    }
    
    // MARK: - Quick Actions
    
    func quickAddFromClipboard() {
        guard let content = NSPasteboard.general.string(forType: .string) else {
            logWarning(.prompt, "No text in clipboard for quick add")
            return
        }
        
        let prompt = Prompt(
            title: TextConstants.defaultPromptTitle,
            content: content,
            tags: [],
            defaultEnhancement: Enhancement()
        )
        
        showPromptEditor(for: prompt, isNew: true)
    }
    
    // MARK: - Settings Management
    
    func showSettings() {
        windowManagementService?.showSettingsWindow(with: appSettings, promptStore: promptStore)
    }
    
    func resetWindowPosition() {
        appSettings.resetWindowPosition()
        menuBarController?.showResetFeedback()
        logInfo(.window, "Reset window position")
    }
    
    // MARK: - Navigation
    
    func navigateUp() {
        paletteController?.navigateUp()
    }
    
    func navigateDown() {
        paletteController?.navigateDown()
    }
    
    func selectQuickSlot(_ slot: Int) {
        if let prompt = promptStore.quickSlotPrompts[slot] {
            insertPromptDirectly(prompt)
        }
    }
    
    // MARK: - State Queries
    
    func isPaletteVisible() -> Bool {
        return windowController?.isPaletteVisible() ?? false
    }
    
    func getSystemHealth() -> SystemHealthStatus {
        return appSetupService?.performSystemHealthCheck() ?? SystemHealthStatus(
            isHealthy: false,
            issues: [.serviceFailure("AppSetupService not available")],
            timestamp: Date()
        )
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        logInfo(.app, "ServiceCoordinator cleanup starting")
        
        keyboardController?.cleanup()
        NotificationCenter.default.removeObserver(self)
        cancellables.removeAll()
        
        // Clear references
        paletteController = nil
        menuBarController = nil
        keyboardController = nil
        windowController = nil
        textInsertionService = nil
        windowManagementService = nil
        onboardingService = nil
        permissionService = nil
        appSetupService = nil
        
        logInfo(.app, "ServiceCoordinator cleanup completed")
    }
}