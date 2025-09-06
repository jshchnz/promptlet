//
//  ServiceProtocols.swift
//  Promptlet
//
//  Core service protocols for dependency injection and better architecture
//

import Foundation
import Cocoa

// MARK: - Text Insertion Service Protocol

@MainActor
protocol TextInsertionServiceProtocol {
    /// Inserts a prompt's content into the currently active application
    /// - Parameters:
    ///   - prompt: The prompt to insert
    ///   - completion: Called when insertion is complete
    func insertPrompt(_ prompt: Prompt, completion: @escaping () -> Void)
    
    /// Inserts a prompt's content directly at current cursor position without app switching
    /// - Parameters:
    ///   - prompt: The prompt to insert
    ///   - completion: Called when insertion is complete
    func insertPromptDirectly(_ prompt: Prompt, completion: @escaping () -> Void)
    
    /// Sets the previous app to return focus to after insertion
    /// - Parameter app: The application to restore focus to
    func setPreviousApp(_ app: NSRunningApplication?)
}

// MARK: - Window Management Service Protocol

@MainActor
protocol WindowManagementServiceProtocol {
    /// Shows the settings window
    /// - Parameters:
    ///   - settings: The app settings object
    ///   - promptStore: The prompt store for managing prompts
    ///   - appDelegate: The app delegate for Sentry testing and other functionality
    func showSettingsWindow(with settings: AppSettings, promptStore: PromptStore, appDelegate: AppDelegate)
    
    /// Shows the prompt editor window
    /// - Parameters:
    ///   - prompt: The prompt to edit
    ///   - onSave: Called when the prompt is saved
    ///   - onCancel: Called when editing is cancelled
    func showPromptEditor(
        for prompt: Prompt,
        onSave: @escaping (Prompt) -> Void,
        onCancel: @escaping () -> Void
    )
    
    /// Closes the prompt editor window
    func closePromptEditor()
    
    /// Indicates if any auxiliary windows are open
    var hasOpenWindows: Bool { get }
    
    /// Closes all auxiliary windows
    func closeAllWindows()
}

// MARK: - Permission Service Protocol

@MainActor
protocol PermissionServiceProtocol {
    /// Checks if accessibility permissions are granted
    var hasAccessibilityPermissions: Bool { get }
    
    /// Requests accessibility permissions from the user
    func requestAccessibilityPermissions()
    
    /// Gets current permission status
    func checkPermissionStatus() -> PermissionStatus
    
    /// Shows permission instruction dialog
    func showPermissionInstructions()
}

// MARK: - Onboarding Service Protocol

@MainActor
protocol OnboardingServiceProtocol {
    /// Indicates if onboarding is needed
    var isOnboardingNeeded: Bool { get }
    
    /// Shows onboarding flow
    /// - Parameter onComplete: Called when onboarding is completed
    func showOnboarding(onComplete: @escaping () -> Void)
    
    /// Sets up test notification handlers for onboarding
    func handleTestNotifications()
}

// MARK: - Data Store Protocols

@MainActor
protocol PromptStoreProtocol {
    var prompts: [Prompt] { get }
    var filteredPrompts: [Prompt] { get }
    var searchText: String { get set }
    
    func addPrompt(_ prompt: Prompt)
    func updatePrompt(_ prompt: Prompt)
    func deletePrompt(_ prompt: Prompt)
    func recordUsage(for promptId: UUID)
}

// MARK: - Controller Protocols

@MainActor
protocol PaletteControllerProtocol {
    var selectedIndex: Int { get }
    
    func navigateUp()
    func navigateDown()
    func selectPrompt(at index: Int)
    func getCurrentPrompt() -> Prompt?
    func reset()
}

// MARK: - Result Types for Better Error Handling

enum ServiceResult<T> {
    case success(T)
    case failure(ServiceError)
}

enum ServiceError: LocalizedError {
    case permissionDenied
    case windowCreationFailed
    case textInsertionFailed
    case invalidInput(String)
    case systemError(Error)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Required permissions not granted"
        case .windowCreationFailed:
            return "Failed to create window"
        case .textInsertionFailed:
            return "Failed to insert text"
        case .invalidInput(let message):
            return "Invalid input: \(message)"
        case .systemError(let error):
            return "System error: \(error.localizedDescription)"
        }
    }
}