//
//  AppSetupService.swift
//  Promptlet
//
//  Handles application initialization and setup logic
//

import Cocoa
import SwiftUI

@MainActor
class AppSetupService: ObservableObject {
    
    // Dependencies
    private weak var promptStore: PromptStore?
    private weak var appSettings: AppSettings?
    private weak var onboardingService: OnboardingService?
    private weak var permissionService: PermissionManager?
    
    // Setup completion callback
    private var setupCompletionCallback: (() -> Void)?
    
    init() {
        logInfo(.app, "AppSetupService initialized")
    }
    
    // MARK: - Public Setup Methods
    
    func performApplicationSetup(
        promptStore: PromptStore,
        appSettings: AppSettings,
        onboardingService: OnboardingService,
        permissionService: PermissionManager,
        completion: @escaping () -> Void
    ) {
        self.promptStore = promptStore
        self.appSettings = appSettings
        self.onboardingService = onboardingService
        self.permissionService = permissionService
        self.setupCompletionCallback = completion
        
        logInfo(.app, "Starting application setup")
        
        // Apply initial settings
        setupInitialAppState()
        
        // Handle onboarding flow
        handleOnboardingFlow()
    }
    
    private func setupInitialAppState() {
        guard let appSettings = appSettings else { return }
        
        // Apply theme
        appSettings.applyTheme()
        
        // Increment launch count for analytics
        appSettings.incrementLaunchCount()
        
        // Set app activation policy
        NSApp.setActivationPolicy(.accessory)
        
        logInfo(.app, "Initial app state configured")
    }
    
    private func handleOnboardingFlow() {
        guard let onboardingService = onboardingService else { return }
        
        if onboardingService.isOnboardingNeeded {
            logInfo(.onboarding, "Onboarding needed, showing onboarding flow")
            onboardingService.showOnboarding { [weak self] in
                self?.completePostOnboardingSetup()
            }
        } else {
            logInfo(.onboarding, "Onboarding already completed")
            completePostOnboardingSetup()
        }
    }
    
    private func completePostOnboardingSetup() {
        setupPermissions()
        finalizeSetup()
    }
    
    private func setupPermissions() {
        guard let permissionService = permissionService else { return }
        
        // Request necessary permissions
        permissionService.requestAccessibilityPermissions()
        
        logInfo(.permission, "Permission setup completed")
    }
    
    private func finalizeSetup() {
        logInfo(.app, "Finalizing application setup")
        
        // Setup test notification handlers for debugging
        setupTestNotificationHandlers()
        
        // Call completion callback
        setupCompletionCallback?()
        
        logSuccess(.app, "Application setup completed successfully")
    }
    
    // MARK: - Test Notification Handlers
    
    private func setupTestNotificationHandlers() {
        NotificationCenter.default.addObserver(
            forName: NotificationNames.testShowPalette,
            object: nil,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: Notification.Name("ShowPaletteAction"), object: nil)
        }
        
        NotificationCenter.default.addObserver(
            forName: NotificationNames.testHidePalette,
            object: nil,
            queue: .main
        ) { _ in
            NotificationCenter.default.post(name: Notification.Name("HidePaletteAction"), object: nil)
        }
        
        logDebug(.app, "Test notification handlers registered")
    }
    
    // MARK: - Configuration Methods
    
    func configureForDevelopment() {
        guard let appSettings = appSettings else { return }
        
        // Enable debug mode for development
        appSettings.debugMode = true
        appSettings.showTechnicalInfo = true
        
        logInfo(.app, "Development configuration applied")
    }
    
    func configureForProduction() {
        guard let appSettings = appSettings else { return }
        
        // Disable debug features for production
        appSettings.debugMode = false
        appSettings.showTechnicalInfo = false
        
        logInfo(.app, "Production configuration applied")
    }
    
    // MARK: - Health Checks
    
    func performSystemHealthCheck() -> SystemHealthStatus {
        var issues: [SystemIssue] = []
        
        // Check permissions
        if let permissionService = permissionService,
           !permissionService.hasAccessibilityPermissions {
            issues.append(.missingPermissions("Accessibility permission required"))
        }
        
        // Check data integrity
        if let promptStore = promptStore,
           promptStore.prompts.isEmpty {
            issues.append(.dataIntegrity("No prompts loaded"))
        }
        
        // Check settings
        if appSettings != nil {
            let config = AppConfiguration.shared.currentConfiguration
            if !config.isValid {
                issues.append(.invalidConfiguration("App configuration is invalid"))
            }
        }
        
        let status = SystemHealthStatus(
            isHealthy: issues.isEmpty,
            issues: issues,
            timestamp: Date()
        )
        
        logInfo(.app, "System health check: \(status.isHealthy ? "Healthy" : "Issues found")")
        return status
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        NotificationCenter.default.removeObserver(self)
        
        promptStore = nil
        appSettings = nil
        onboardingService = nil
        permissionService = nil
        setupCompletionCallback = nil
        
        logInfo(.app, "AppSetupService cleaned up")
    }
}

// MARK: - Supporting Types

struct SystemHealthStatus {
    let isHealthy: Bool
    let issues: [SystemIssue]
    let timestamp: Date
    
    var description: String {
        if isHealthy {
            return "System is healthy"
        } else {
            let issueDescriptions = issues.map { $0.description }.joined(separator: ", ")
            return "Issues found: \(issueDescriptions)"
        }
    }
}

enum SystemIssue {
    case missingPermissions(String)
    case dataIntegrity(String)
    case invalidConfiguration(String)
    case serviceFailure(String)
    
    var description: String {
        switch self {
        case .missingPermissions(let detail):
            return "Missing permissions: \(detail)"
        case .dataIntegrity(let detail):
            return "Data integrity issue: \(detail)"
        case .invalidConfiguration(let detail):
            return "Configuration issue: \(detail)"
        case .serviceFailure(let detail):
            return "Service failure: \(detail)"
        }
    }
}

// MARK: - Setup Configuration

struct AppSetupConfiguration {
    let enableDevelopmentFeatures: Bool
    let skipOnboarding: Bool
    let enableDiagnostics: Bool
    let customTheme: ThemeMode?
    
    static let `default` = AppSetupConfiguration(
        enableDevelopmentFeatures: false,
        skipOnboarding: false,
        enableDiagnostics: false,
        customTheme: nil
    )
    
    static let development = AppSetupConfiguration(
        enableDevelopmentFeatures: true,
        skipOnboarding: true,
        enableDiagnostics: true,
        customTheme: .dark
    )
}