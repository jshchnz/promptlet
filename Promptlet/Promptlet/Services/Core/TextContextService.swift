//
//  TextContextService.swift
//  Promptlet
//
//  Handles accessibility API interactions to get text content and selections
//  from other applications for advanced text placement modes.
//

import Cocoa
import Foundation
import ApplicationServices

@MainActor
class TextContextService: TextContextServiceProtocol {
    
    // MARK: - Text Context Information
    
    struct TextContext {
        let existingContent: String
        let selectedText: String
        let hasSelection: Bool
        let appName: String
        
        static let empty = TextContext(
            existingContent: "",
            selectedText: "",
            hasSelection: false,
            appName: ""
        )
    }
    
    // MARK: - Public Methods
    
    /// Gets the current text context from the frontmost application
    /// Returns empty context if accessibility access is denied or unavailable
    func getCurrentTextContext() -> TextContext {
        guard hasAccessibilityAccess() else {
            logWarning(.textInsertion, "Accessibility access not available for text context")
            return .empty
        }
        
        guard let frontmostApp = NSWorkspace.shared.frontmostApplication else {
            logWarning(.textInsertion, "No frontmost application found")
            return .empty
        }
        
        let appName = frontmostApp.localizedName ?? "Unknown"
        logDebug(.textInsertion, "Getting text context for app: \(appName)")
        
        // Get the focused text element using accessibility API
        if let focusedElement = getFocusedTextElement() {
            let existingContent = getTextContent(from: focusedElement)
            let selectedText = getSelectedText(from: focusedElement)
            let hasSelection = !selectedText.isEmpty
            
            logDebug(.textInsertion, "Text context - existing: \(existingContent.count) chars, selected: \(selectedText.count) chars, hasSelection: \(hasSelection)")
            
            return TextContext(
                existingContent: existingContent,
                selectedText: selectedText,
                hasSelection: hasSelection,
                appName: appName
            )
        }
        
        logDebug(.textInsertion, "Could not get focused text element, returning empty context")
        return TextContext(
            existingContent: "",
            selectedText: "",
            hasSelection: false,
            appName: appName
        )
    }
    
    /// Sets the text content of the currently focused text element
    /// This is used for advanced placement modes that need to replace entire content
    func setTextContent(_ content: String) -> Bool {
        guard hasAccessibilityAccess() else {
            logWarning(.textInsertion, "Accessibility access not available for setting text content")
            return false
        }
        
        guard let focusedElement = getFocusedTextElement() else {
            logWarning(.textInsertion, "No focused text element found for setting content")
            return false
        }
        
        return setTextContent(content, in: focusedElement)
    }
    
    // MARK: - Private Accessibility Methods
    
    private func hasAccessibilityAccess() -> Bool {
        return AXIsProcessTrusted()
    }
    
    private func getFocusedTextElement() -> AXUIElement? {
        // Get the system-wide focused element
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            AXUIElementCreateSystemWide(),
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success,
              let focusedElementRef = focusedElement,
              CFGetTypeID(focusedElementRef) == AXUIElementGetTypeID() else {
            logDebug(.textInsertion, "Could not get focused UI element: \(result.rawValue)")
            return nil
        }
        
        let element = focusedElementRef as! AXUIElement
        
        // Check if this element supports text operations
        if isTextElement(element) {
            return element
        }
        
        // If not, try to find a text element within it
        return findTextElement(in: element)
    }
    
    private func isTextElement(_ element: AXUIElement) -> Bool {
        // Check if element has text-related attributes
        let textAttributes = [
            kAXValueAttribute as CFString,
            kAXSelectedTextAttribute as CFString,
            kAXSelectedTextRangeAttribute as CFString
        ]
        
        for attribute in textAttributes {
            var value: CFTypeRef?
            let result = AXUIElementCopyAttributeValue(element, attribute, &value)
            if result == .success {
                return true
            }
        }
        
        return false
    }
    
    private func findTextElement(in parent: AXUIElement) -> AXUIElement? {
        // Try to get children and search for text elements
        var children: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(parent, kAXChildrenAttribute as CFString, &children)
        
        guard result == .success,
              let childrenArray = children as? [AXUIElement] else {
            return nil
        }
        
        // Search through children for text elements
        for child in childrenArray {
            if isTextElement(child) {
                return child
            }
            
            // Recursively search in child elements (limited depth to avoid infinite loops)
            if let textElement = findTextElement(in: child) {
                return textElement
            }
        }
        
        return nil
    }
    
    private func getTextContent(from element: AXUIElement) -> String {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
        
        guard result == .success, let textValue = value as? String else {
            logDebug(.textInsertion, "Could not get text value from element: \(result.rawValue)")
            return ""
        }
        
        return textValue
    }
    
    private func getSelectedText(from element: AXUIElement) -> String {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXSelectedTextAttribute as CFString, &value)
        
        guard result == .success, let selectedText = value as? String else {
            logDebug(.textInsertion, "Could not get selected text from element: \(result.rawValue)")
            return ""
        }
        
        return selectedText
    }
    
    private func setTextContent(_ content: String, in element: AXUIElement) -> Bool {
        let result = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, content as CFString)
        
        if result == .success {
            logDebug(.textInsertion, "Successfully set text content: \(content.count) characters")
            return true
        } else {
            logError(.textInsertion, "Failed to set text content: \(result.rawValue)")
            return false
        }
    }
}

// MARK: - Extension for Logging

extension TextContextService {
    private func logDebug(_ category: LogCategory, _ message: String) {
        #if DEBUG
        print("[DEBUG][\(category)] \(message)")
        #endif
    }
    
    private func logWarning(_ category: LogCategory, _ message: String) {
        print("[WARNING][\(category)] \(message)")
    }
    
    private func logError(_ category: LogCategory, _ message: String) {
        print("[ERROR][\(category)] \(message)")
    }
}