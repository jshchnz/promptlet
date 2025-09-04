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
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 600),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        self.isReleasedWhenClosed = false
        self.center()
        self.isMovableByWindowBackground = true
        self.backgroundColor = NSColor.clear
        
        // Set minimum and maximum size to prevent resizing
        self.minSize = NSSize(width: 760, height: 600)
        self.maxSize = NSSize(width: 760, height: 600)
        
        // Floating level brings to front but allows system dialogs on top
        self.level = .floating
    }
    
    func showOnboarding(with view: some View) {
        self.contentView = NSHostingView(rootView: view)
        self.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Bring to absolute front initially
        self.orderFrontRegardless()
    }
}