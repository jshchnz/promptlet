//
//  FloatingPanel.swift
//  Promptlet
//
//  Reusable floating panel for palette and other overlay windows
//

import Cocoa

class FloatingPanel: NSPanel {
    
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.hudWindow, .utilityWindow, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        setupPanel()
    }
    
    private func setupPanel() {
        // Essential window settings
        isReleasedWhenClosed = false
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        hasShadow = true
        animationBehavior = .utilityWindow
        isMovableByWindowBackground = true
        hidesOnDeactivate = false  // Don't hide when losing focus
        
        // Start invisible to prevent flash
        alphaValue = 0
    }
    
    // Allow the panel to become key window for text input
    override var canBecomeKey: Bool {
        return true
    }
    
    // Allow the panel to become main window if needed
    override var canBecomeMain: Bool {
        return true
    }
}