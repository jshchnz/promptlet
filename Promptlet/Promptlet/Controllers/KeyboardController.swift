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
    
    init(delegate: KeyboardControllerDelegate, appSettings: AppSettings) {
        self.delegate = delegate
        self.appSettings = appSettings
        super.init()
    }
    
    func setupGlobalHotkey() {
        cleanupGlobalHotkey()
        
        // Global monitor for when our app is not active
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return }
            
            // Check if show palette shortcut matches
            if let showPaletteShortcut = self.appSettings.getShortcut(for: .showPalette),
               showPaletteShortcut.matches(event: event) {
                self.delegate?.keyboardShowPalette()
            }
        }
        
        // Local monitor for when our app is active
        localEventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Check if show palette shortcut matches
            if let showPaletteShortcut = self.appSettings.getShortcut(for: .showPalette),
               showPaletteShortcut.matches(event: event) {
                self.delegate?.keyboardShowPalette()
                return nil // Consume the event to prevent the beep
            }
            return event
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
        // Reload shortcuts by re-setting up the monitors
        setupGlobalHotkey()
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
    
    func simulatePaste() {
        // Use CGEvent to simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        
        // Create keyboard events for Cmd+V
        let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true) // Cmd down
        let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)   // V down
        let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)    // V up
        let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)  // Cmd up
        
        // Set the command flag
        cmdDown?.flags = .maskCommand
        vDown?.flags = .maskCommand
        vUp?.flags = .maskCommand
        cmdUp?.flags = .maskCommand
        
        // Post the events
        cmdDown?.post(tap: .cghidEventTap)
        vDown?.post(tap: .cghidEventTap)
        vUp?.post(tap: .cghidEventTap)
        cmdUp?.post(tap: .cghidEventTap)
        
        print("[KeyboardController] Pasted via keyboard simulation")
    }
    
    func cleanup() {
        cleanupGlobalHotkey()
        stopPaletteKeyboardMonitoring()
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