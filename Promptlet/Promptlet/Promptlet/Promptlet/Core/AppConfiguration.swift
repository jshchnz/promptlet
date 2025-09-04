//
//  AppConfiguration.swift
//  Promptlet
//
//  Centralized application configuration and settings management
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Configuration Protocol

@MainActor
protocol AppConfigurationProtocol {
    var defaultTheme: ThemeMode { get }
    var defaultPosition: DefaultPosition { get }
    var enableAnimationsByDefault: Bool { get }
    var defaultKeyboardShortcuts: [ShortcutAction: KeyboardShortcut] { get }
    
    func validateSettings() -> Bool
    func resetToDefaults() -> AppConfigurationData
}

// MARK: - Configuration Data Model

struct AppConfigurationData: Codable {
    let themeMode: ThemeMode
    let defaultPosition: DefaultPosition
    let enableAnimations: Bool
    let showMenuBarIcon: Bool
    let showQuickSlotsInMenuBar: Bool
    let menuBarQuickSlotCount: Int
    let debugMode: Bool
    let showTechnicalInfo: Bool
    
    // Validation
    var isValid: Bool {
        menuBarQuickSlotCount >= 1 && 
        menuBarQuickSlotCount <= AppConfig.QuickSlots.maxSlots
    }
}

// MARK: - App Configuration Manager

@MainActor
class AppConfiguration: AppConfigurationProtocol, ObservableObject {
    static let shared = AppConfiguration()
    
    // MARK: - Default Values
    
    var defaultTheme: ThemeMode { .auto }
    var defaultPosition: DefaultPosition { .center }
    var enableAnimationsByDefault: Bool { AppConfig.Defaults.enableAnimations }
    
    var defaultKeyboardShortcuts: [ShortcutAction: KeyboardShortcut] {
        KeyboardShortcut.defaultShortcuts
    }
    
    // MARK: - Configuration Properties
    
    @Published private(set) var currentConfiguration: AppConfigurationData
    
    private init() {
        self.currentConfiguration = AppConfigurationData.defaultConfiguration
        logInfo(.app, "AppConfiguration initialized with defaults")
    }
    
    // MARK: - Configuration Management
    
    func updateConfiguration(_ newConfig: AppConfigurationData) {
        guard newConfig.isValid else {
            logError(.settings, "Invalid configuration provided")
            return
        }
        
        currentConfiguration = newConfig
        logInfo(.settings, "Configuration updated successfully")
    }
    
    func validateSettings() -> Bool {
        return currentConfiguration.isValid
    }
    
    func resetToDefaults() -> AppConfigurationData {
        let defaultConfig = AppConfigurationData.defaultConfiguration
        currentConfiguration = defaultConfig
        logInfo(.settings, "Configuration reset to defaults")
        return defaultConfig
    }
    
    // MARK: - Theme Management
    
    func applyTheme(_ theme: ThemeMode) {
        switch theme {
        case .light:
            NSApp.appearance = NSAppearance(named: .aqua)
        case .dark:
            NSApp.appearance = NSAppearance(named: .darkAqua)
        case .auto:
            NSApp.appearance = nil
        }
        logDebug(.settings, "Applied theme: \(theme.rawValue)")
    }
    
    // MARK: - Window Positioning
    
    func getWindowPosition(for windowType: WindowType, 
                          savedPosition: String? = nil) -> NSPoint? {
        switch currentConfiguration.defaultPosition {
        case .center:
            return calculateCenterPosition(for: windowType)
        case .topCenter:
            return calculateTopCenterPosition(for: windowType)
        case .remember:
            if let saved = savedPosition, !saved.isEmpty {
                let position = NSPointFromString(saved)
                // Validate that the position is reasonable (not CGPoint.zero unless intended)
                if position.x >= 0 && position.y >= 0 {
                    return position
                }
            }
            return calculateCenterPosition(for: windowType)
        }
    }
    
    private func calculateCenterPosition(for windowType: WindowType) -> NSPoint? {
        guard let screen = NSScreen.main else { return nil }
        
        let screenFrame = screen.visibleFrame
        let windowSize = windowType.size
        let x = (screenFrame.width - windowSize.width) / 2 + screenFrame.origin.x
        let y = (screenFrame.height - windowSize.height) / 2 + screenFrame.origin.y
        
        return NSPoint(x: x, y: y)
    }
    
    private func calculateTopCenterPosition(for windowType: WindowType) -> NSPoint? {
        guard let screen = NSScreen.main else { return nil }
        
        let screenFrame = screen.visibleFrame
        let windowSize = windowType.size
        let x = (screenFrame.width - windowSize.width) / 2 + screenFrame.origin.x
        let y = screenFrame.origin.y + screenFrame.height - (screenFrame.height * 0.3) - windowSize.height
        
        return NSPoint(x: x, y: y)
    }
    
    // MARK: - Validation Rules
    
    func validateQuickSlotConfiguration(_ count: Int) -> Bool {
        count >= 1 && count <= AppConfig.QuickSlots.maxSlots
    }
    
    func validateKeyboardShortcut(_ shortcut: KeyboardShortcut, 
                                 for action: ShortcutAction) -> Bool {
        return shortcut.isValid(for: action)
    }
    
    // MARK: - Configuration Export/Import
    
    func exportConfiguration() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        
        do {
            let data = try encoder.encode(currentConfiguration)
            logInfo(.settings, "Configuration exported successfully")
            return data
        } catch {
            logError(.settings, "Failed to export configuration: \(error)")
            throw ConfigurationError.exportFailed(error)
        }
    }
    
    func importConfiguration(from data: Data) throws {
        let decoder = JSONDecoder()
        
        do {
            let config = try decoder.decode(AppConfigurationData.self, from: data)
            guard config.isValid else {
                throw ConfigurationError.invalidConfiguration
            }
            
            updateConfiguration(config)
            logInfo(.settings, "Configuration imported successfully")
        } catch {
            logError(.settings, "Failed to import configuration: \(error)")
            throw ConfigurationError.importFailed(error)
        }
    }
    
    // MARK: - Static Factory Methods
    
    static func createDefaultConfiguration() -> AppConfigurationData {
        return AppConfigurationData.defaultConfiguration
    }
}

// MARK: - Supporting Types

enum WindowType {
    case palette
    case settings
    case promptEditor
    case onboarding
    
    var size: NSSize {
        switch self {
        case .palette:
            return NSSize(width: WindowSize.Palette.width, 
                         height: WindowSize.Palette.height)
        case .settings:
            return NSSize(width: WindowSize.Settings.width, 
                         height: WindowSize.Settings.height)
        case .promptEditor:
            return NSSize(width: WindowSize.PromptEditor.width, 
                         height: WindowSize.PromptEditor.height)
        case .onboarding:
            return NSSize(width: WindowSize.Onboarding.width, 
                         height: WindowSize.Onboarding.height)
        }
    }
}

enum ConfigurationError: LocalizedError {
    case invalidConfiguration
    case exportFailed(Error)
    case importFailed(Error)
    case validationFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidConfiguration:
            return "Configuration contains invalid values"
        case .exportFailed(let error):
            return "Failed to export configuration: \(error.localizedDescription)"
        case .importFailed(let error):
            return "Failed to import configuration: \(error.localizedDescription)"
        case .validationFailed(let message):
            return "Configuration validation failed: \(message)"
        }
    }
}

// MARK: - Configuration Extensions

extension AppConfigurationData {
    static let `default` = AppConfigurationData.defaultConfiguration
    
    static let defaultConfiguration = AppConfigurationData(
        themeMode: .auto,
        defaultPosition: .center,
        enableAnimations: AppConfig.Defaults.enableAnimations,
        showMenuBarIcon: AppConfig.Defaults.showMenuBarIcon,
        showQuickSlotsInMenuBar: AppConfig.Defaults.showQuickSlotsInMenuBar,
        menuBarQuickSlotCount: AppConfig.Defaults.menuBarQuickSlotCount,
        debugMode: AppConfig.Defaults.debugMode,
        showTechnicalInfo: AppConfig.Defaults.showTechnicalInfo
    )
    
    func with(themeMode: ThemeMode? = nil,
              defaultPosition: DefaultPosition? = nil,
              enableAnimations: Bool? = nil,
              showMenuBarIcon: Bool? = nil,
              showQuickSlotsInMenuBar: Bool? = nil,
              menuBarQuickSlotCount: Int? = nil,
              debugMode: Bool? = nil,
              showTechnicalInfo: Bool? = nil) -> AppConfigurationData {
        
        return AppConfigurationData(
            themeMode: themeMode ?? self.themeMode,
            defaultPosition: defaultPosition ?? self.defaultPosition,
            enableAnimations: enableAnimations ?? self.enableAnimations,
            showMenuBarIcon: showMenuBarIcon ?? self.showMenuBarIcon,
            showQuickSlotsInMenuBar: showQuickSlotsInMenuBar ?? self.showQuickSlotsInMenuBar,
            menuBarQuickSlotCount: menuBarQuickSlotCount ?? self.menuBarQuickSlotCount,
            debugMode: debugMode ?? self.debugMode,
            showTechnicalInfo: showTechnicalInfo ?? self.showTechnicalInfo
        )
    }
}