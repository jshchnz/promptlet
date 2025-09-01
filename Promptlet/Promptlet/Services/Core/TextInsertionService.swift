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
    
    func insertPrompt(_ prompt: Prompt, completion: @escaping () -> Void) {
        logPerformanceStart("text_insertion")
        
        let content = prompt.renderedContent(with: [:])
        
        // Save current clipboard
        let previousClipboard = NSPasteboard.general.string(forType: .string)
        
        // Set prompt content to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // Restore focus to the original app
        if let app = previousApp {
            logDebug(.textInsertion, "Restoring focus to: \(app.localizedName ?? "unknown")")
            app.activate()
            
            // Wait for focus to restore, then paste
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.simulatePaste()
                
                // Restore previous clipboard after a delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    if let previous = previousClipboard {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(previous, forType: .string)
                    }
                    
                    logPerformanceEnd("text_insertion", "Text insertion completed")
                    completion()
                }
                
                logSuccess(.textInsertion, "Successfully inserted prompt: \(prompt.title)")
            }
        } else {
            completion()
        }
    }
    
    func setPreviousApp(_ app: NSRunningApplication?) {
        previousApp = app
        if let app = app {
            logDebug(.app, "Saved previous app: \(app.localizedName ?? "none")")
        }
    }
    
    private func simulatePaste() {
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
    }
}