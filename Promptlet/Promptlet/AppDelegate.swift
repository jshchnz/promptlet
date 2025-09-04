//
//  AppDelegate.swift
//  Promptlet
//
//  Refactored to use service-based architecture for better maintainability
//

import Cocoa
import SwiftUI

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Core Components
    var promptStore: PromptStore = PromptStore()
    let appSettings = AppSettings()
    
    // MARK: - Service Coordination
    private var serviceCoordinator: ServiceCoordinator!
    private var diagnosticService: DiagnosticService!
    private var appSetupService: AppSetupService!
    
    // MARK: - Controllers
    private var paletteController: PaletteController!
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
        
        // Initialize analytics first
        AnalyticsService.shared.initialize()
        
        initializeServices()
        initializeControllers()
        setupServiceCoordination()
        performApplicationSetup()
    }
    
    private func initializeServices() {
        // Core services
        textInsertionService = TextInsertionService()
        windowManagementService = WindowManagementService()
        onboardingService = OnboardingService(settings: appSettings, promptStore: promptStore)
        permissionService = PermissionManager.shared
        
        // Coordination services
        serviceCoordinator = ServiceCoordinator(promptStore: promptStore, appSettings: appSettings)
        diagnosticService = DiagnosticService()
        appSetupService = AppSetupService()
        
        logInfo(.app, "Services initialized")
    }
    
    private func initializeControllers() {
        paletteController = PaletteController(store: promptStore)
        menuBarController = MenuBarController(delegate: self, promptStore: promptStore, appSettings: appSettings)
        keyboardController = KeyboardController(delegate: self, appSettings: appSettings)
        windowController = WindowController(delegate: self)
        
        logInfo(.app, "Controllers initialized")
    }
    
    private func setupServiceCoordination() {
        // Register all components with the service coordinator
        serviceCoordinator.registerControllers(
            paletteController: paletteController,
            menuBarController: menuBarController,
            keyboardController: keyboardController,
            windowController: windowController
        )
        
        serviceCoordinator.registerServices(
            textInsertionService: textInsertionService,
            windowManagementService: windowManagementService,
            onboardingService: onboardingService,
            permissionService: permissionService,
            appSetupService: appSetupService
        )
        
        // Register diagnostic service
        diagnosticService.registerServices(
            keyboardController: keyboardController,
            permissionService: permissionService
        )
        
        logInfo(.app, "Service coordination setup completed")
    }
    
    private func performApplicationSetup() {
        appSetupService.performApplicationSetup(
            promptStore: promptStore,
            appSettings: appSettings,
            onboardingService: onboardingService,
            permissionService: permissionService
        ) { [weak self] in
            self?.completeSetup()
        }
    }
    
    private func completeSetup() {
        keyboardController.setupGlobalHotkey()
        
        // Track app launch with analytics
        let isFirstLaunch = appSettings.launchCount <= 1
        AnalyticsService.shared.trackAppLaunch(isFirstLaunch: isFirstLaunch)
        AnalyticsService.shared.startSession()
        
        // Show the palette for the first time after setup
        DispatchQueue.main.asyncAfter(deadline: .now() + Timing.focusRestoreDelay) { [weak self] in
            self?.serviceCoordinator.showPalette()
        }
        
        logSuccess(.app, "Application setup completed successfully")
    }
    
    // MARK: - Cleanup
    
    func applicationWillTerminate(_ notification: Notification) {
        logInfo(.app, "Application terminating, cleaning up resources")
        
        // Track app termination and cleanup analytics
        trackAnalytics(.appTerminated)
        AnalyticsService.shared.shutdown()
        
        serviceCoordinator.cleanup()
        appSetupService.cleanup()
        NotificationCenter.default.removeObserver(self)
    }
}

// MARK: - MenuBarDelegate

extension AppDelegate: MenuBarDelegate {
    func menuBarShowPalette() {
        serviceCoordinator.showPalette()
    }
    
    func menuBarQuickAddFromClipboard() {
        serviceCoordinator.quickAddFromClipboard()
    }
    
    func menuBarInsertRecentPrompt(_ promptId: UUID) {
        guard let prompt = promptStore.prompts.first(where: { $0.id == promptId }) else {
            return
        }
        trackPromptAction(.promptInserted, promptId: promptId, method: "menu_bar_recent")
        serviceCoordinator.insertPrompt(prompt)
    }
    
    func menuBarInsertQuickSlotPrompt(_ promptId: UUID) {
        guard let prompt = promptStore.prompts.first(where: { $0.id == promptId }) else {
            return
        }
        trackAnalytics(.menuBarPromptUsed, properties: ["type": "quick_slot"])
        trackPromptAction(.promptInserted, promptId: promptId, method: "menu_bar_quick_slot")
        serviceCoordinator.insertPrompt(prompt)
    }
    
    func menuBarOpenSettings() {
        trackAnalytics(.settingsOpened, properties: ["source": "menu_bar"])
        serviceCoordinator.showSettings()
    }
    
    func menuBarResetWindowPosition() {
        trackAnalytics(.windowPositionReset, properties: ["source": "menu_bar"])
        serviceCoordinator.resetWindowPosition()
    }
    
    // MARK: - Diagnostic Menu Methods (delegated to DiagnosticService)
    
    func menuBarShowShortcutStatus() {
        diagnosticService.showShortcutStatus(appSettings: appSettings)
    }
    
    func menuBarShowPermissionStatus() {
        diagnosticService.showPermissionStatus()
    }
    
    func menuBarResetShortcuts() {
        diagnosticService.resetShortcuts()
    }
    
    func menuBarShowDebugLogs() {
        diagnosticService.showDebugLogs()
    }
}

// MARK: - KeyboardControllerDelegate

extension AppDelegate: KeyboardControllerDelegate {
    func keyboardShowPalette() {
        serviceCoordinator.showPalette()
    }
    
    func keyboardHidePalette() {
        serviceCoordinator.hidePalette()
    }
    
    func keyboardNavigateUp() {
        serviceCoordinator.navigateUp()
    }
    
    func keyboardNavigateDown() {
        serviceCoordinator.navigateDown()
    }
    
    func keyboardQuickSlot(_ slot: Int) {
        serviceCoordinator.selectQuickSlot(slot)
    }
    
    func keyboardNewPrompt() {
        serviceCoordinator.createNewPrompt()
    }
    
    func isPaletteVisible() -> Bool {
        return serviceCoordinator.isPaletteVisible()
    }
}

// MARK: - WindowControllerDelegate

extension AppDelegate: WindowControllerDelegate {
    func windowDidMove() {
        // Window position is handled by the WindowController itself
        // No additional action needed from AppDelegate
    }
}