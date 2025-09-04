//
//  AnalyticsService.swift
//  Promptlet
//
//  Privacy-first analytics service using PostHog
//  Tracks user interactions to improve the app while respecting privacy
//

import Foundation
import PostHog
import AppKit

enum AnalyticsEvent: String, CaseIterable {
    // App Lifecycle Events
    case appLaunched = "app_launched"
    case firstLaunch = "first_launch"
    case sessionStarted = "session_started"
    case sessionEnded = "session_ended"
    case appTerminated = "app_terminated"
    
    // Onboarding Events
    case onboardingStarted = "onboarding_started"
    case onboardingStepCompleted = "onboarding_step_completed"
    case onboardingCompleted = "onboarding_completed"
    case onboardingSkipped = "onboarding_skipped"
    case permissionGranted = "permission_granted"
    case permissionDenied = "permission_denied"
    
    // Prompt Management Events
    case promptCreated = "prompt_created"
    case promptEdited = "prompt_edited"
    case promptDeleted = "prompt_deleted"
    case promptDuplicated = "prompt_duplicated"
    case promptImported = "prompt_imported"
    case promptExported = "prompt_exported"
    case promptsClearedAll = "prompts_cleared_all"
    case promptsResetToDefault = "prompts_reset_to_default"
    
    // Usage & Engagement Events
    case promptInserted = "prompt_inserted"
    case promptInsertedDirect = "prompt_inserted_direct"
    case paletteOpened = "palette_opened"
    case paletteClosed = "palette_closed"
    case searchPerformed = "search_performed"
    case quickSlotUsed = "quick_slot_used"
    case menuBarPromptUsed = "menu_bar_prompt_used"
    case promptFavorited = "prompt_favorited"
    case promptUnfavorited = "prompt_unfavorited"
    
    // Organization Events
    case categoryCreated = "category_created"
    case categoryDeleted = "category_deleted"
    case categoryRenamed = "category_renamed"
    case promptMovedToCategory = "prompt_moved_to_category"
    case promptArchived = "prompt_archived"
    case promptUnarchived = "prompt_unarchived"
    case promptsReordered = "prompts_reordered"
    
    // Settings & Customization Events
    case settingsOpened = "settings_opened"
    case themeChanged = "theme_changed"
    case shortcutChanged = "shortcut_changed"
    case shortcutsReset = "shortcuts_reset"
    case windowPositionReset = "window_position_reset"
    case quickSlotAssigned = "quick_slot_assigned"
    case quickSlotRemoved = "quick_slot_removed"
    
    // Feature Discovery Events
    case menuBarIconToggled = "menu_bar_icon_toggled"
    case animationsToggled = "animations_toggled"
    case debugModeToggled = "debug_mode_toggled"
    case sortModeChanged = "sort_mode_changed"
    
    // Performance & Error Events
    case permissionError = "permission_error"
    case keyboardShortcutFailed = "keyboard_shortcut_failed"
    case textInsertionFailed = "text_insertion_failed"
    case importFailed = "import_failed"
    case exportFailed = "export_failed"
    case performanceWarning = "performance_warning"
}

@MainActor
class AnalyticsService: ObservableObject {
    static let shared = AnalyticsService()
    
    private let isAnalyticsEnabled: Bool = true
    
    private var sessionStartTime: Date?
    private var eventQueue: [String: [String: Any]] = [:]
    private let debounceInterval: TimeInterval = 1.0
    
    private init() {
        // Analytics is always enabled
    }
    
    // MARK: - PostHog Setup
    
    func initialize() {
        
        let config = PostHogConfig(
            apiKey: "phc_AmV2QyV6js0IOwSykkpu7ykLFob1kSj6kP7SnB7owAh",
            host: "https://us.i.posthog.com"
        )
        
        // Privacy-focused configuration
        config.captureApplicationLifecycleEvents = false // We handle these manually
        config.debug = true // Enable debug logging to troubleshoot connectivity
        
        PostHogSDK.shared.setup(config)
        
        // Set user properties that are privacy-safe
        PostHogSDK.shared.identify(
            getAnonymousUserId(),
            userProperties: getBaseUserProperties()
        )
        
        logSuccess(.app, "PostHog analytics initialized")
        
        // Test network connectivity to PostHog
        testNetworkConnectivity()
    }
    
    // MARK: - Event Tracking
    
    func track(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
        
        var enrichedProperties = getBaseEventProperties()
        enrichedProperties.merge(properties) { _, new in new }
        
        // Add privacy-safe metadata
        enrichedProperties["$process_person_profile"] = false // Disable person profile processing
        
        let eventKey = "\(event.rawValue)_\(Date().timeIntervalSince1970)"
        eventQueue[eventKey] = enrichedProperties
        
        // Debounce events to avoid spam
        DispatchQueue.main.asyncAfter(deadline: .now() + debounceInterval) { [weak self] in
            self?.flushEvent(eventKey, event: event.rawValue)
        }
        
        logDebug(.performance, "Analytics event queued: \(event.rawValue)")
    }
    
    private func flushEvent(_ eventKey: String, event: String) {
        guard let properties = eventQueue[eventKey] else { return }
        eventQueue.removeValue(forKey: eventKey)
        
        // Log event details for debugging
        logInfo(.performance, "Sending analytics event: \(event) with \(properties.count) properties")
        
        PostHogSDK.shared.capture(event, properties: properties)
        logDebug(.performance, "Analytics event sent: \(event)")
    }
    
    // MARK: - Session Management
    
    func startSession() {
        
        sessionStartTime = Date()
        track(.sessionStarted)
        
        logInfo(.app, "Analytics session started")
    }
    
    func endSession() {
        guard let startTime = sessionStartTime else { return }
        
        let sessionDuration = Date().timeIntervalSince(startTime)
        track(.sessionEnded, properties: [
            "session_duration_seconds": Int(sessionDuration)
        ])
        
        sessionStartTime = nil
        logInfo(.app, "Analytics session ended - duration: \(Int(sessionDuration))s")
    }
    
    // MARK: - Privacy-Safe Properties
    
    private func getAnonymousUserId() -> String {
        // Generate or retrieve a persistent anonymous ID
        let userDefaults = UserDefaults.standard
        if let existingId = userDefaults.string(forKey: "anonymousUserId") {
            return existingId
        }
        
        let newId = UUID().uuidString
        userDefaults.set(newId, forKey: "anonymousUserId")
        return newId
    }
    
    private func getBaseUserProperties() -> [String: Any] {
        var properties: [String: Any] = [:]
        
        // App information
        if let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
            properties["app_version"] = appVersion
        }
        
        if let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            properties["build_number"] = buildNumber
        }
        
        // System information (privacy-safe)
        properties["os_version"] = ProcessInfo.processInfo.operatingSystemVersionString
        properties["app_locale"] = Locale.current.identifier
        
        // Screen information (for UI optimization)
        if let screen = NSScreen.main {
            properties["screen_width"] = Int(screen.frame.width)
            properties["screen_height"] = Int(screen.frame.height)
        }
        
        return properties
    }
    
    private func getBaseEventProperties() -> [String: Any] {
        var properties = getBaseUserProperties()
        
        // Session information
        properties["timestamp"] = ISO8601DateFormatter().string(from: Date())
        
        if let sessionStartTime = sessionStartTime {
            properties["session_duration_so_far"] = Int(Date().timeIntervalSince(sessionStartTime))
        }
        
        return properties
    }
    
    // MARK: - Convenience Methods for Common Events
    
    func trackAppLaunch(isFirstLaunch: Bool = false) {
        if isFirstLaunch {
            track(.firstLaunch)
        } else {
            track(.appLaunched)
        }
    }
    
    func trackPromptAction(_ event: AnalyticsEvent, promptId: UUID? = nil, method: String? = nil) {
        var properties: [String: Any] = [:]
        
        if let method = method {
            properties["method"] = method
        }
        
        // We hash the UUID for privacy - no direct ID tracking
        if let promptId = promptId {
            properties["prompt_hash"] = promptId.uuidString.hash
        }
        
        track(event, properties: properties)
    }
    
    func trackSettingsChange(_ setting: String, oldValue: Any?, newValue: Any?) {
        var properties: [String: Any] = [
            "setting_name": setting
        ]
        
        // Only track the type of change, not the actual values for privacy
        if let oldValue = oldValue, let newValue = newValue {
            properties["value_type"] = type(of: newValue)
            properties["changed"] = "\(oldValue)" != "\(newValue)"
        }
        
        track(.settingsOpened, properties: properties)
    }
    
    func trackError(_ event: AnalyticsEvent, error: String, context: String? = nil) {
        var properties: [String: Any] = [
            "error_message": error
        ]
        
        if let context = context {
            properties["context"] = context
        }
        
        track(event, properties: properties)
    }
    
    func trackPerformance(_ event: AnalyticsEvent, duration: TimeInterval, operation: String) {
        track(event, properties: [
            "operation": operation,
            "duration_ms": Int(duration * 1000)
        ])
    }
    
    // MARK: - Network Connectivity
    
    private func testNetworkConnectivity() {
        guard let url = URL(string: "https://us.i.posthog.com/health") else {
            logError(.app, "Invalid PostHog URL")
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    logError(.app, "PostHog connectivity test failed: \(error.localizedDescription)")
                } else if let httpResponse = response as? HTTPURLResponse {
                    logInfo(.app, "PostHog connectivity test: HTTP \(httpResponse.statusCode)")
                } else {
                    logInfo(.app, "PostHog connectivity test completed")
                }
            }
        }
        task.resume()
    }
    
    // MARK: - Cleanup
    
    func shutdown() {
        endSession()
        PostHogSDK.shared.flush()
        logInfo(.app, "Analytics service shutdown")
    }
}

// MARK: - Global Convenience Functions

@MainActor
func trackAnalytics(_ event: AnalyticsEvent, properties: [String: Any] = [:]) {
    AnalyticsService.shared.track(event, properties: properties)
}

@MainActor
func trackPromptAction(_ event: AnalyticsEvent, promptId: UUID? = nil, method: String? = nil) {
    AnalyticsService.shared.trackPromptAction(event, promptId: promptId, method: method)
}

@MainActor
func trackError(_ event: AnalyticsEvent, error: String, context: String? = nil) {
    AnalyticsService.shared.trackError(event, error: error, context: context)
}