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
    private let promptStore: PromptStore
    private let textContextService: TextContextServiceProtocol
    static var isPerformingKeyboardSimulation = false
    
    init(promptStore: PromptStore, textContextService: TextContextServiceProtocol) {
        self.promptStore = promptStore
        self.textContextService = textContextService
    }
    
    func insertPrompt(_ prompt: Prompt, completion: @escaping () -> Void) {
        logPerformanceStart("text_insertion")
        let startTime = Date()
        
        // Get the appropriate enhancement for this prompt and current app
        let enhancement = promptStore.getEnhancement(for: prompt)
        logDebug(.textInsertion, "Using enhancement: placement=\(enhancement.placement.rawValue), transforms=\(enhancement.transforms.map { $0.rawValue })")
        
        // Render the basic content with variable substitutions
        let basicContent = prompt.renderedContent(with: [:])
        
        // Apply enhancement transforms and formatting
        let enhancementResult = applyEnhancement(enhancement, to: basicContent)
        let content = enhancementResult.content
        let useAccessibilityAPI = enhancementResult.useAccessibilityAPI
        let finalEnhancement = enhancementResult.enhancement
        
        logDebug(.textInsertion, "Enhanced content: \(content.count) chars, useAccessibilityAPI: \(useAccessibilityAPI)")
        
        // Handle different insertion methods based on placement mode
        if useAccessibilityAPI {
            // Use accessibility API to replace content directly
            insertUsingAccessibilityAPI(content: content, enhancement: finalEnhancement, completion: completion, startTime: startTime, prompt: prompt)
            return
        }
        
        // Use standard clipboard insertion for cursor placement
        insertUsingClipboard(content: content, completion: completion, startTime: startTime, prompt: prompt)
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
        
        // Get the appropriate enhancement for this prompt and current app
        let enhancement = promptStore.getEnhancement(for: prompt)
        logDebug(.textInsertion, "Using enhancement for direct insertion: placement=\(enhancement.placement.rawValue), transforms=\(enhancement.transforms.map { $0.rawValue })")
        
        // Render the basic content with variable substitutions
        let basicContent = prompt.renderedContent(with: [:])
        
        // Apply enhancement transforms and formatting
        let enhancementResult = applyEnhancement(enhancement, to: basicContent)
        let content = enhancementResult.content
        let useAccessibilityAPI = enhancementResult.useAccessibilityAPI
        let finalEnhancement = enhancementResult.enhancement
        
        logDebug(.textInsertion, "Enhanced content for direct insertion: \(content.count) chars, useAccessibilityAPI: \(useAccessibilityAPI)")
        
        // Handle different insertion methods based on placement mode
        if useAccessibilityAPI {
            // Use accessibility API to replace content directly
            insertUsingAccessibilityAPI(content: content, enhancement: finalEnhancement, completion: completion, startTime: Date(), prompt: prompt)
            return
        }
        
        // Use standard clipboard insertion for direct insertion (no app switching needed)
        insertUsingClipboard(content: content, completion: completion, startTime: Date(), prompt: prompt)
    }
    
    func setPreviousApp(_ app: NSRunningApplication?) {
        previousApp = app
        if let app = app {
            logDebug(.app, "Saved previous app: \(app.localizedName ?? "none")")
        }
    }
    
    private func insertUsingAccessibilityAPI(content: String, enhancement: Enhancement, completion: @escaping () -> Void, startTime: Date, prompt: Prompt) {
        logDebug(.textInsertion, "Starting accessibility API insertion with enhancement: \(enhancement.placement.rawValue)")
        
        // First, restore focus to the previous app if needed
        if let app = previousApp {
            logDebug(.textInsertion, "Restoring focus to: \(app.localizedName ?? "Unknown")")
            app.activate()
            
            // Wait for focus to be restored before getting text context
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.performAccessibilityInsertion(content: content, enhancement: enhancement, completion: completion, startTime: startTime, prompt: prompt)
            }
        } else {
            // No previous app, proceed immediately
            performAccessibilityInsertion(content: content, enhancement: enhancement, completion: completion, startTime: startTime, prompt: prompt)
        }
    }
    
    private func performAccessibilityInsertion(content: String, enhancement: Enhancement, completion: @escaping () -> Void, startTime: Date, prompt: Prompt) {
        // Now that focus is restored, get text context from the target app
        let textContext = textContextService.getCurrentTextContext()
        logDebug(.textInsertion, "Got text context from app: \(textContext.appName), existing: \(textContext.existingContent.count) chars, selected: \(textContext.selectedText.count) chars")
        
        // Apply enhancement with the retrieved text context
        let finalContent: String
        switch enhancement.placement {
        case .cursor:
            // This shouldn't happen since cursor placement uses clipboard method
            finalContent = enhancement.apply(to: content, with: nil, existingContent: "")
            
        case .top, .bottom:
            finalContent = enhancement.apply(to: content, with: textContext.selectedText, existingContent: textContext.existingContent)
            logDebug(.textInsertion, "Applied \(enhancement.placement.rawValue) placement: \(finalContent.count) chars")
            
        case .wrap:
            if !textContext.hasSelection {
                logWarning(.textInsertion, "Wrap placement requires selected text, but no selection found. Falling back to cursor placement.")
                // Fallback to clipboard insertion for cursor placement
                insertUsingClipboard(content: enhancement.apply(to: content, with: nil, existingContent: ""), completion: completion, startTime: startTime, prompt: prompt)
                return
            }
            
            finalContent = enhancement.apply(to: content, with: textContext.selectedText, existingContent: textContext.existingContent)
            logDebug(.textInsertion, "Applied wrap placement with \(textContext.selectedText.count) chars selection")
        }
        
        // Try to set the content using accessibility API
        let success = textContextService.setTextContent(finalContent)
        
        if success {
            logSuccess(.textInsertion, "Successfully inserted prompt using accessibility API: \(prompt.title)")
        } else {
            logError(.textInsertion, "Failed to insert prompt using accessibility API, falling back to clipboard method")
            
            // Fallback to clipboard insertion
            insertUsingClipboard(content: finalContent, completion: completion, startTime: startTime, prompt: prompt)
            return
        }
        
        // Track performance
        let duration = Date().timeIntervalSince(startTime)
        if duration > 2.0 {
            AnalyticsService.shared.trackPerformance(.performanceWarning, duration: duration, operation: "accessibility_text_insertion")
        }
        
        logPerformanceEnd("text_insertion", "Accessibility text insertion completed")
        completion()
    }
    
    private func insertUsingClipboard(content: String, completion: @escaping () -> Void, startTime: Date, prompt: Prompt) {
        // Save current clipboard
        let previousClipboard = NSPasteboard.general.string(forType: .string)
        
        // Set prompt content to clipboard
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
        
        // Restore focus to the original app if needed
        if let app = previousApp {
            app.activate()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.performClipboardVerificationAndPaste(expectedContent: content, prompt: prompt, previousClipboard: previousClipboard, completion: completion, startTime: startTime)
            }
        } else {
            performClipboardVerificationAndPaste(expectedContent: content, prompt: prompt, previousClipboard: previousClipboard, completion: completion, startTime: startTime)
        }
    }
    
    private func applyEnhancement(_ enhancement: Enhancement, to content: String) -> (content: String, useAccessibilityAPI: Bool, enhancement: Enhancement) {
        switch enhancement.placement {
        case .cursor:
            // For cursor placement, use normal paste behavior - NO accessibility API calls needed
            let enhancedContent = enhancement.apply(to: content, with: nil, existingContent: "")
            logDebug(.textInsertion, "Applied cursor placement: \(enhancedContent.count) chars")
            return (enhancedContent, false, enhancement)
            
        case .top, .bottom, .wrap:
            // For advanced placement modes, defer text context retrieval until after focus is restored
            logDebug(.textInsertion, "Deferring \(enhancement.placement.rawValue) placement until after focus restoration")
            return (content, true, enhancement)
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