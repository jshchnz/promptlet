//
//  Constants.swift
//  Promptlet
//
//  Centralized constants for improved maintainability and reduced magic numbers
//

import Foundation
import AppKit

// MARK: - Window Dimensions

enum WindowSize {
    enum Palette {
        static let width: CGFloat = 500
        static let height: CGFloat = 350
    }
    
    enum Settings {
        static let width: CGFloat = 900
        static let height: CGFloat = 650
    }
    
    enum PromptEditor {
        static let width: CGFloat = 500
        static let height: CGFloat = 550
    }
    
    enum Onboarding {
        static let width: CGFloat = 600
        static let height: CGFloat = 500
    }
}

// MARK: - Timing Constants

enum Timing {
    static let fadeInDuration: TimeInterval = 0.15
    static let fadeOutDuration: TimeInterval = 0.10
    static let scaleEffectFrom: CGFloat = 0.96
    static let scaleEffectTo: CGFloat = 1.0
    
    static let feedbackDuration: TimeInterval = 1.0
    static let resetFeedbackDuration: TimeInterval = 0.5
    
    static let clipboardRestoreDelay: TimeInterval = 0.5
    static let focusRestoreDelay: TimeInterval = 0.3
    static let keyboardSimulationDelay: TimeInterval = 0.1
    
    static let debounceDelay: TimeInterval = 0.5
}

// MARK: - UserDefaults Keys

enum UserDefaultsKeys {
    static let prompts = "com.promptlet.prompts"
    static let preferences = "com.promptlet.preferences"
    static let categories = "com.promptlet.prompts.categories"
    static let windowPosition = "PaletteWindowPosition"
    
    enum Preferences {
        static let defaultPlacement = "com.promptlet.preferences.defaultPlacement"
        static let lastApp = "com.promptlet.preferences.lastApp"
        static let paletteSortMode = "com.promptlet.preferences.paletteSortMode"
    }
}

// MARK: - System & Hardware

enum System {
    enum KeyCodes {
        static let command: UInt16 = 0x37
        static let v: UInt16 = 0x09
        static let escape: UInt16 = 53
        static let `return`: UInt16 = 36
        static let upArrow: UInt16 = 126
        static let downArrow: UInt16 = 125
        static let period: UInt16 = 47
        static let n: UInt16 = 45
    }
    
    enum ModifierFlags {
        static let command = NSEvent.ModifierFlags.command.rawValue
        static let shift = NSEvent.ModifierFlags.shift.rawValue
        static let option = NSEvent.ModifierFlags.option.rawValue
        static let control = NSEvent.ModifierFlags.control.rawValue
    }
}

// MARK: - Performance & Monitoring

enum Performance {
    static let healthCheckInterval: TimeInterval = 30.0
    static let permissionMonitorInterval: TimeInterval = 1.0
    static let maxRetries: Int = 5
    static let maxLogs: Int = 1000
    static let clipboardVerificationRetries: Int = 3
}

// MARK: - UI Constants

enum UI {
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 32
    }
    
    enum CornerRadius {
        static let small: CGFloat = 5
        static let medium: CGFloat = 8
        static let large: CGFloat = 10
    }
    
    enum Opacity {
        static let disabled: Double = 0.5
        static let secondary: Double = 0.8
        static let background: Double = 0.2
    }
    
    enum FontSize {
        static let caption: CGFloat = 10
        static let small: CGFloat = 11
        static let body: CGFloat = 13
        static let title: CGFloat = 17
        static let largeTitle: CGFloat = 28
    }
}

// MARK: - App Configuration

enum AppConfig {
    static let bundleIdentifier = "justjoshing.Promptlet"
    static let developmentTeam = "Z69AA836Q7"
    static let minMacOSVersion = "14.0"
    
    enum QuickSlots {
        static let maxSlots = 9
        static let defaultMenuBarCount = 5
        static let minSlot = 1
    }
    
    enum Defaults {
        static let launchCount = 0
        static let onboardingVersion = 0
        static let menuBarQuickSlotCount = 5
        static let enableAnimations = true
        static let showMenuBarIcon = true
        static let showQuickSlotsInMenuBar = true
        static let debugMode = false
        static let showTechnicalInfo = false
    }
}

// MARK: - Search & Filtering

enum Search {
    static let tagPrefix = "#"
    static let modePrefix = "mode:"
    static let categoryPrefix = "category:"
    static let uncategorizedKeywords = ["uncategorized", "none"]
    static let maxRecentPrompts = 5
    static let maxDebugLogLines = 50
}

// MARK: - Text & Content

enum TextConstants {
    static let defaultPromptTitle = "New Prompt"
    static let defaultPromptContent = ""
    static let copyTitleSuffix = " Copy"
    static let searchPlaceholder = "Type to search..."
    
    enum SystemPreferences {
        static let accessibilityURL = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        static let privacyURL = "x-apple.systempreferences:com.apple.preference.security?Privacy"
    }
    
    enum MenuBar {
        static let paletteTitle = "⌘."
        static let statusItemTitle = "Promptlet"
        static let checkmark = "✓"
        static let resetSymbol = "↻"
    }
}

// MARK: - Notification Names

enum NotificationNames {
    static let shortcutsChanged = Notification.Name("shortcutsChanged")
    static let testShowPalette = Notification.Name("TestShowPalette")
    static let testHidePalette = Notification.Name("TestHidePalette")
}

// MARK: - Error Messages

enum ErrorMessages {
    static let emptyTitle = "Cannot add prompt with empty title"
    static let promptNotFound = "Cannot update prompt: not found"
    static let clipboardVerificationFailed = "Clipboard verification failed"
    static let accessibilityPermissionRequired = "Accessibility permission is required"
    static let windowCreationFailed = "Failed to create window"
    static let invalidData = "Invalid data provided"
    static let noPromptsToExport = "No prompts available to export"
}

// MARK: - Sample Data

enum SampleData {
    static let categories = ["Work", "Personal", "Templates"]
}