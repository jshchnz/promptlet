//
//  WindowManagementService.swift
//  Promptlet
//
//  Centralized window management for auxiliary windows
//  
//  This service handles:
//  - Settings window creation and management
//  - Prompt editor window lifecycle
//  - Window positioning and state management
//  - Memory management for window references
//

import Cocoa
import SwiftUI

@MainActor
class WindowManagementService: WindowManagementServiceProtocol {
    private var settingsWindow: NSWindow?
    private var promptEditorWindow: NSWindow?
    
    // MARK: - Settings Window
    
    func showSettingsWindow(with settings: AppSettings, promptStore: PromptStore) {
        if settingsWindow == nil {
            let settingsView = SettingsView(settings: settings, promptStore: promptStore)
            let hostingView = NSHostingView(rootView: settingsView)
            
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 750, height: 550),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            
            window.title = "Promptlet Settings"
            window.contentView = hostingView
            window.center()
            window.isReleasedWhenClosed = false
            window.tabbingMode = .disallowed
            
            settingsWindow = window
            logSuccess(.window, "Settings window created")
        }
        
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        logDebug(.settings, "Settings window opened")
    }
    
    // MARK: - Prompt Editor Window
    
    func showPromptEditor(
        for prompt: Prompt,
        onSave: @escaping (Prompt) -> Void,
        onCancel: @escaping () -> Void
    ) {
        logDebug(.ui, "Showing prompt editor for: \(prompt.title)")
        
        let editorView = PromptEditorView(
            prompt: prompt,
            onSave: onSave,
            onCancel: { [weak self] in
                self?.closePromptEditor()
                onCancel()
            }
        )
        
        let hostingView = NSHostingView(rootView: editorView)
        
        // Create or reuse window
        if promptEditorWindow == nil {
            let window = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Edit Prompt"
            window.isReleasedWhenClosed = false
            window.level = .floating
            window.center()
            promptEditorWindow = window
            
            logSuccess(.window, "Prompt editor window created")
        }
        
        promptEditorWindow?.contentView = hostingView
        promptEditorWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func closePromptEditor() {
        promptEditorWindow?.close()
        promptEditorWindow = nil
        logDebug(.window, "Prompt editor window closed")
    }
    
    // MARK: - Window State
    
    var hasOpenWindows: Bool {
        (settingsWindow?.isVisible ?? false) || (promptEditorWindow?.isVisible ?? false)
    }
    
    func closeAllWindows() {
        settingsWindow?.close()
        promptEditorWindow?.close()
        settingsWindow = nil
        promptEditorWindow = nil
        logInfo(.window, "All auxiliary windows closed")
    }
}