//
//  KeyboardController.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import Cocoa

@MainActor
class KeyboardController: NSObject {
    private var globalEventMonitor: Any?
    private var localEventMonitor: Any?
    private var paletteLocalEventMonitor: Any?
    private weak var delegate: KeyboardControllerDelegate?
    private var appSettings: AppSettings
    
    // Health check and recovery
    private var healthCheckTimer: Timer?
    private var lastHealthCheck: Date = Date()
    private var monitorRegistrationFailures: Int = 0
    private let maxRetries = 5
    private let healthCheckInterval: TimeInterval = 30.0  // Check every 30 seconds
    
    // System event observers
    private var systemEventObservers: [NSObjectProtocol] = []
    
    init(delegate: KeyboardControllerDelegate, appSettings: AppSettings) {
        self.delegate = delegate
        self.appSettings = appSettings
        super.init()
        setupSystemEventObservers()
        startHealthMonitoring()
    }
    
    func setupGlobalHotkey() {
        cleanupGlobalHotkey()
        
        logInfo(.keyboard, "Setting up global hotkey monitors")
        
        // Global monitor for when our app is not active
        do {
            globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { 
                    logDebug(.keyboard, "Global monitor: self is nil")
                    return 
                }
                
                // Update last activity timestamp
                self.lastHealthCheck = Date()
                
                // Check if show palette shortcut matches
                if let showPaletteShortcut = self.appSettings.getShortcut(for: .showPalette),
                   showPaletteShortcut.matches(event: event) {
                    logDebug(.keyboard, "Global shortcut triggered: \(showPaletteShortcut.displayString)")
                    self.delegate?.keyboardShowPalette()
                    return
                }
                
                // Skip if we're currently performing keyboard simulation (avoid feedback loop)
                if TextInsertionService.isPerformingKeyboardSimulation {
                    return
                }
                
                // Skip events without modifiers (performance optimization)
                let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
                let hasModifiers = !event.modifierFlags.intersection(relevantFlags).isEmpty
                if !hasModifiers {
                    return
                }
                
                // Check quick slot shortcuts (only when palette is NOT visible)
                guard let delegate = self.delegate, !delegate.isPaletteVisible() else { 
                    return 
                }
                
                let quickSlotActions: [(ShortcutAction, Int)] = [
                    (.quickSlot1, 1), (.quickSlot2, 2), (.quickSlot3, 3),
                    (.quickSlot4, 4), (.quickSlot5, 5), (.quickSlot6, 6),
                    (.quickSlot7, 7), (.quickSlot8, 8), (.quickSlot9, 9)
                ]
                
                for (action, slot) in quickSlotActions {
                    if let shortcut = self.appSettings.getShortcut(for: action),
                       shortcut.matches(event: event) {
                        logDebug(.keyboard, "Quick slot \(slot) triggered: \(shortcut.displayString)")
                        delegate.keyboardQuickSlot(slot)
                        return
                    }
                }
            }
            
            if globalEventMonitor != nil {
                logSuccess(.keyboard, "Global event monitor registered successfully")
                monitorRegistrationFailures = 0
            } else {
                logError(.keyboard, "Failed to register global event monitor")
                monitorRegistrationFailures += 1
            }
        }
        
        // Local monitor for when our app is active
        do {
            localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                guard let self = self else { 
                    logDebug(.keyboard, "Local monitor: self is nil")
                    return event 
                }
                
                // Update last activity timestamp
                self.lastHealthCheck = Date()
                
                // Check if show palette shortcut matches
                if let showPaletteShortcut = self.appSettings.getShortcut(for: .showPalette),
                   showPaletteShortcut.matches(event: event) {
                    logDebug(.keyboard, "Local shortcut triggered: \(showPaletteShortcut.displayString)")
                    self.delegate?.keyboardShowPalette()
                    return nil // Consume the event to prevent the beep
                }
                
                // Skip if we're currently performing keyboard simulation (avoid feedback loop)
                if TextInsertionService.isPerformingKeyboardSimulation {
                    return event
                }
                
                // Skip events without modifiers (performance optimization)
                let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
                let hasModifiers = !event.modifierFlags.intersection(relevantFlags).isEmpty
                if !hasModifiers {
                    return event
                }
                
                // Check quick slot shortcuts (only when palette is NOT visible)
                guard let delegate = self.delegate, !delegate.isPaletteVisible() else { 
                    return event 
                }
                
                let quickSlotActions: [(ShortcutAction, Int)] = [
                    (.quickSlot1, 1), (.quickSlot2, 2), (.quickSlot3, 3),
                    (.quickSlot4, 4), (.quickSlot5, 5), (.quickSlot6, 6),
                    (.quickSlot7, 7), (.quickSlot8, 8), (.quickSlot9, 9)
                ]
                
                for (action, slot) in quickSlotActions {
                    if let shortcut = self.appSettings.getShortcut(for: action),
                       shortcut.matches(event: event) {
                        logDebug(.keyboard, "Quick slot \(slot) triggered: \(shortcut.displayString)")
                        delegate.keyboardQuickSlot(slot)
                        return nil // Consume the event to prevent the beep
                    }
                }
                
                return event
            }
            
            if localEventMonitor != nil {
                logSuccess(.keyboard, "Local event monitor registered successfully")
            } else {
                logError(.keyboard, "Failed to register local event monitor")
                monitorRegistrationFailures += 1
            }
        }
        
        // If we failed to register monitors, try recovery
        if monitorRegistrationFailures > 0 && monitorRegistrationFailures <= maxRetries {
            logWarning(.keyboard, "Monitor registration failed, attempting recovery in 2 seconds...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.setupGlobalHotkey()
            }
        } else if monitorRegistrationFailures > maxRetries {
            logError(.keyboard, "Max retries reached for monitor registration, manual intervention may be required")
        }
    }
    
    func cleanupGlobalHotkey() {
        if let monitor = globalEventMonitor {
            NSEvent.removeMonitor(monitor)
            globalEventMonitor = nil
        }
        if let monitor = localEventMonitor {
            NSEvent.removeMonitor(monitor)
            localEventMonitor = nil
        }
    }
    
    func reloadShortcuts() {
        logInfo(.keyboard, "Reloading keyboard shortcuts")
        // Reload shortcuts by re-setting up the monitors
        setupGlobalHotkey()
        
        // Reset failure counter on manual reload
        monitorRegistrationFailures = 0
    }
    
    func startPaletteKeyboardMonitoring() {
        stopPaletteKeyboardMonitoring()
        
        paletteLocalEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self,
                  let delegate = self.delegate,
                  delegate.isPaletteVisible() else {
                return event
            }
            
            // Check each shortcut action
            
            // Close palette
            if let shortcut = self.appSettings.getShortcut(for: .closePalette),
               shortcut.matches(event: event) {
                delegate.keyboardHidePalette()
                return nil
            }
            
            // Navigate up
            if let shortcut = self.appSettings.getShortcut(for: .navigateUp),
               shortcut.matches(event: event) {
                delegate.keyboardNavigateUp()
                return nil
            }
            
            // Navigate down
            if let shortcut = self.appSettings.getShortcut(for: .navigateDown),
               shortcut.matches(event: event) {
                delegate.keyboardNavigateDown()
                return nil
            }
            
            // Insert prompt (Return) - let TextField handle it for text input
            if let shortcut = self.appSettings.getShortcut(for: .insertPrompt),
               shortcut.matches(event: event) {
                // Return is handled by TextField when typing
                return event
            }
            
            // New prompt
            if let shortcut = self.appSettings.getShortcut(for: .newPrompt),
               shortcut.matches(event: event) {
                delegate.keyboardNewPrompt()
                return nil
            }
            
            // Quick slots
            let quickSlotActions: [(ShortcutAction, Int)] = [
                (.quickSlot1, 1), (.quickSlot2, 2), (.quickSlot3, 3),
                (.quickSlot4, 4), (.quickSlot5, 5), (.quickSlot6, 6),
                (.quickSlot7, 7), (.quickSlot8, 8), (.quickSlot9, 9)
            ]
            
            for (action, slot) in quickSlotActions {
                if let shortcut = self.appSettings.getShortcut(for: action),
                   shortcut.matches(event: event) {
                    delegate.keyboardQuickSlot(slot)
                    return nil
                }
            }
            
            return event
        }
    }
    
    func stopPaletteKeyboardMonitoring() {
        if let monitor = paletteLocalEventMonitor {
            NSEvent.removeMonitor(monitor)
            paletteLocalEventMonitor = nil
        }
    }
    
    
    func cleanup() {
        logInfo(.keyboard, "Cleaning up keyboard controller")
        cleanupGlobalHotkey()
        stopPaletteKeyboardMonitoring()
        stopHealthMonitoring()
        cleanupSystemEventObservers()
    }
    
    // MARK: - Health Monitoring and Recovery
    
    private func startHealthMonitoring() {
        logDebug(.keyboard, "Starting keyboard shortcut health monitoring")
        healthCheckTimer = Timer.scheduledTimer(withTimeInterval: healthCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.performHealthCheck()
            }
        }
    }
    
    private func stopHealthMonitoring() {
        healthCheckTimer?.invalidate()
        healthCheckTimer = nil
        logDebug(.keyboard, "Stopped health monitoring")
    }
    
    private func performHealthCheck() {
        let timeSinceLastActivity = Date().timeIntervalSince(lastHealthCheck)
        
        // If it's been a while since we've seen any keyboard activity and we haven't had recent failures,
        // this might indicate the monitors are no longer working
        if timeSinceLastActivity > healthCheckInterval * 2 && monitorRegistrationFailures == 0 {
            logDebug(.keyboard, "Performing health check - \(Int(timeSinceLastActivity))s since last activity")
            
            // Check if monitors are still registered
            if !areMonitorsHealthy() {
                logWarning(.keyboard, "Health check failed, re-registering monitors")
                setupGlobalHotkey()
            }
        }
    }
    
    private func areMonitorsHealthy() -> Bool {
        // Basic health check - ensure monitors are not nil
        let globalHealthy = globalEventMonitor != nil
        let localHealthy = localEventMonitor != nil
        
        if !globalHealthy {
            logWarning(.keyboard, "Global event monitor is nil")
        }
        if !localHealthy {
            logWarning(.keyboard, "Local event monitor is nil")
        }
        
        return globalHealthy && localHealthy
    }
    
    // MARK: - System Event Observers
    
    private func setupSystemEventObservers() {
        // Observe system sleep/wake events
        let sleepObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            logDebug(.keyboard, "System will sleep - preparing monitors")
            Task { @MainActor in
                self?.handleSystemSleep()
            }
        }
        
        let wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            logDebug(.keyboard, "System did wake - re-registering monitors")
            Task { @MainActor in
                self?.handleSystemWake()
            }
        }
        
        // Observe app activation changes
        let activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            logDebug(.keyboard, "App became active - verifying monitors")
            Task { @MainActor in
                self?.handleAppActivation()
            }
        }
        
        let deactivationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            logDebug(.keyboard, "App resigned active")
            Task { @MainActor in
                self?.handleAppDeactivation()
            }
        }
        
        systemEventObservers = [sleepObserver, wakeObserver, activationObserver, deactivationObserver]
        
        logInfo(.keyboard, "System event observers registered")
    }
    
    private func cleanupSystemEventObservers() {
        for observer in systemEventObservers {
            // Try to remove from both notification centers since we can't reliably distinguish
            // which center the observer was added to
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
            NotificationCenter.default.removeObserver(observer)
        }
        systemEventObservers.removeAll()
        logDebug(.keyboard, "System event observers cleaned up")
    }
    
    private func handleSystemSleep() {
        // System is going to sleep - monitors might be disrupted
        logInfo(.keyboard, "Handling system sleep")
        stopHealthMonitoring()
    }
    
    private func handleSystemWake() {
        // System woke up - re-register monitors to ensure they're working
        logInfo(.keyboard, "Handling system wake, re-registering monitors")
        monitorRegistrationFailures = 0  // Reset failure counter
        setupGlobalHotkey()
        startHealthMonitoring()
    }
    
    private func handleAppActivation() {
        // App became active - good time to verify monitors are working
        if !areMonitorsHealthy() {
            logWarning(.keyboard, "App activation detected unhealthy monitors, re-registering")
            setupGlobalHotkey()
        }
    }
    
    private func handleAppDeactivation() {
        // App resigned active - this is when global monitor becomes most important
        // Update timestamp to ensure health check doesn't trigger immediately
        lastHealthCheck = Date()
    }
    
    // MARK: - Public Diagnostics
    
    func getMonitorStatus() -> (global: Bool, local: Bool, failureCount: Int) {
        return (
            global: globalEventMonitor != nil,
            local: localEventMonitor != nil,
            failureCount: monitorRegistrationFailures
        )
    }
    
    func forceReregisterMonitors() {
        logInfo(.keyboard, "Force re-registering monitors")
        monitorRegistrationFailures = 0
        setupGlobalHotkey()
    }
    
    func getHealthStatus() -> String {
        let status = getMonitorStatus()
        let timeSinceLastActivity = Int(Date().timeIntervalSince(lastHealthCheck))
        
        return "Global: \(status.global ? "✓" : "✗"), Local: \(status.local ? "✓" : "✗"), Failures: \(status.failureCount), Last Activity: \(timeSinceLastActivity)s ago"
    }
}

@MainActor
protocol KeyboardControllerDelegate: AnyObject {
    func keyboardShowPalette()
    func keyboardHidePalette()
    func keyboardNavigateUp()
    func keyboardNavigateDown()
    func keyboardQuickSlot(_ slot: Int)
    func keyboardNewPrompt()
    func isPaletteVisible() -> Bool
}