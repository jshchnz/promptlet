//
//  OnboardingWindow.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import SwiftUI
import AppKit

class OnboardingWindow: NSWindow {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        self.title = "Welcome to Promptlet"
        self.isReleasedWhenClosed = false
        self.center()
        self.isMovableByWindowBackground = false
        self.titlebarAppearsTransparent = false
        self.standardWindowButton(.miniaturizeButton)?.isHidden = true
        self.standardWindowButton(.zoomButton)?.isHidden = true
        
        // Set minimum and maximum size to prevent resizing
        self.minSize = NSSize(width: 600, height: 500)
        self.maxSize = NSSize(width: 600, height: 500)
        
        // Make window appear on top
        self.level = .floating
    }
    
    func showOnboarding(with view: some View) {
        self.contentView = NSHostingView(rootView: view)
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}