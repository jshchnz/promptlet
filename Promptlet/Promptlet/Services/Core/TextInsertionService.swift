//
//  TextInsertionService.swift
//  Promptlet
//
//  Handles text insertion logic and clipboard management
//  
//  This service manages the complex flow of:
//  1. Saving the current clipboard content
//  2. Placing prompt content in clipboard
//  3. Restoring focus to the previous application
//  4. Simulating Cmd+V to paste the content
//  5. Restoring the original clipboard content
//

import Cocoa
import Foundation

@MainActor
class TextInsertionService: TextInsertionServiceProtocol {
    private var previousApp: NSRunningApplication?
    static var isPerformingKeyboardSimulation = false
    
    func insertPrompt(_ prompt: Prompt, completion: @escaping () -> Void) {
        logPerformanceStart("text_insertion")
        let startTime = Date()
        
        let content = prompt.renderedContent(with: [:])
        
        // Save current clipboard
        let previousClipboard = NSPasteboard.general.string(forType: .string)
        logDebug(.textInsertion, "Saved clipboard content: \(previousClipboard?.prefix(50) ?? "nil")...")
        
        // Set prompt content to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // Verify clipboard was set correctly
        let verifyClipboard = NSPasteboard.general.string(forType: .string)
        if verifyClipboard != content {
            logError(.textInsertion, "Clipboard verification failed. Expected: \(content), Got: \(verifyClipboard ?? "nil")")
            trackError(.textInsertionFailed, error: "Clipboard verification failed", context: "initial_set")
        } else {
            logDebug(.textInsertion, "Clipboard set successfully: \(content)")
        }
        
        // Restore focus to the original app
        if let app = previousApp {
            logDebug(.textInsertion, "Restoring focus to: \(app.localizedName ?? "unknown")")
            app.activate()
            
            // Wait longer for focus to restore, then verify and paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.performClipboardVerificationAndPaste(expectedContent: content, prompt: prompt, previousClipboard: previousClipboard, completion: completion, startTime: startTime)
            }
        } else {
            logWarning(.textInsertion, "No previous app to restore focus to")
            completion()
        }
    }
    
    private func performClipboardVerificationAndPaste(expectedContent: String, prompt: Prompt, previousClipboard: String?, completion: @escaping () -> Void, attempt: Int = 1, startTime: Date = Date()) {
        // Verify clipboard still contains our content
        let currentClipboard = NSPasteboard.general.string(forType: .string)
        
        if currentClipboard != expectedContent {
            logWarning(.textInsertion, "Clipboard content changed before paste. Expected: \(expectedContent), Got: \(currentClipboard ?? "nil")")
            
            if attempt <= 3 {
                logDebug(.textInsertion, "Retrying clipboard set (attempt \(attempt + 1)/3)")
                
                // Re-set the clipboard content and retry
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(expectedContent, forType: .string)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    self?.performClipboardVerificationAndPaste(expectedContent: expectedContent, prompt: prompt, previousClipboard: previousClipboard, completion: completion, attempt: attempt + 1, startTime: startTime)
                }
                return
            } else {
                logError(.textInsertion, "Failed to maintain clipboard content after 3 attempts")
                trackError(.textInsertionFailed, error: "Failed to maintain clipboard content after retries", context: "clipboard_persistence")
            }
        }
        
        // Perform the paste
        self.simulatePaste()
        
        // Restore previous clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let previous = previousClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
                logDebug(.textInsertion, "Restored previous clipboard content")
            }
            
            // Track performance
            let duration = Date().timeIntervalSince(startTime)
            if duration > 2.0 { // Log slow operations
                AnalyticsService.shared.trackPerformance(.performanceWarning, duration: duration, operation: "text_insertion")
            }
            
            logPerformanceEnd("text_insertion", "Text insertion completed")
            completion()
        }
        
        logSuccess(.textInsertion, "Successfully inserted prompt: \(prompt.title)")
    }
    
    func insertPromptDirectly(_ prompt: Prompt, completion: @escaping () -> Void) {
        logPerformanceStart("direct_text_insertion")
        
        let content = prompt.renderedContent(with: [:])
        
        // Save current clipboard
        let previousClipboard = NSPasteboard.general.string(forType: .string)
        logDebug(.textInsertion, "Saved clipboard content for direct insertion: \(previousClipboard?.prefix(50) ?? "nil")...")
        
        // Set prompt content to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // Verify clipboard was set correctly
        let verifyClipboard = NSPasteboard.general.string(forType: .string)
        if verifyClipboard != content {
            logError(.textInsertion, "Clipboard verification failed for direct insertion. Expected: \(content), Got: \(verifyClipboard ?? "nil")")
        } else {
            logDebug(.textInsertion, "Clipboard set successfully for direct insertion: \(content)")
        }
        
        // Perform immediate paste without app switching
        self.simulatePaste()
        
        // Restore previous clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            if let previous = previousClipboard {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(previous, forType: .string)
                logDebug(.textInsertion, "Restored previous clipboard content after direct insertion")
            }
            
            logPerformanceEnd("direct_text_insertion", "Direct text insertion completed")
            completion()
        }
        
        logSuccess(.textInsertion, "Successfully performed direct insertion of prompt: \(prompt.title)")
    }
    
    func setPreviousApp(_ app: NSRunningApplication?) {
        previousApp = app
        if let app = app {
            logDebug(.app, "Saved previous app: \(app.localizedName ?? "none")")
        }
    }
    
    private func simulatePaste() {
        // Set flag to indicate we're performing keyboard simulation
        TextInsertionService.isPerformingKeyboardSimulation = true
        
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
        
        logDebug(.textInsertion, "Pasted via keyboard simulation")
        
        // Clear the flag after a short delay to allow events to propagate
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            TextInsertionService.isPerformingKeyboardSimulation = false
        }
    }
}