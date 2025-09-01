//
//  WindowController.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import Cocoa
import SwiftUI

@MainActor
class WindowController: NSObject, NSWindowDelegate {
    private var paletteWindow: NSWindow?
    private var onboardingWindow: OnboardingWindow?
    private weak var delegate: WindowControllerDelegate?
    private var currentAnimationContext: NSAnimationContext?
    
    init(delegate: WindowControllerDelegate) {
        self.delegate = delegate
        super.init()
    }
    
    func createPaletteWindow(view: some View, appSettings: AppSettings) {
        let hostingView = NSHostingView(rootView: view)
        
        // Enable layer backing for smoother animations
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 10
        hostingView.layerContentsRedrawPolicy = .onSetNeedsDisplay
        
        // Create custom palette panel
        let window = FloatingPanel(contentRect: NSRect(x: 0, y: 0, width: 500, height: 350))
        
        window.contentView = hostingView
        window.delegate = self
        
        // Apply current theme
        if appSettings.theme != .auto {
            window.appearance = appSettings.theme == .dark ? NSAppearance(named: .darkAqua) : NSAppearance(named: .aqua)
        }
        
        paletteWindow = window
        
        logSuccess(.window, "Palette window created")
    }
    
    func showPalette(appSettings: AppSettings) {
        guard let window = paletteWindow else { return }
        
        // Cancel any ongoing animation
        currentAnimationContext?.completionHandler = nil
        currentAnimationContext = nil
        
        // Position window while invisible (only if not already visible)
        if window.alphaValue < 0.1 {
            positionWindow(window, appSettings: appSettings)
        }
        
        // Make window key but keep current alpha
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Set initial scale if window is hidden
        if window.alphaValue < 0.1 {
            window.contentView?.layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1.0)
        }
        
        // Animate fade in with scale effect
        NSAnimationContext.runAnimationGroup({ [weak self] context in
            context.duration = 0.15
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            context.allowsImplicitAnimation = true
            
            self?.currentAnimationContext = context
            
            // Scale and fade in
            window.animator().alphaValue = 1.0
            
            // Animate to full scale
            if let contentView = window.contentView {
                contentView.layer?.transform = CATransform3DIdentity
            }
        }, completionHandler: { [weak self] in
            self?.currentAnimationContext = nil
        })
    }
    
    func hidePalette() {
        logDebug(.window, "Hiding palette")
        guard let window = paletteWindow else { return }
        
        // Cancel any ongoing animation
        currentAnimationContext?.completionHandler = nil
        currentAnimationContext = nil
        
        // Animate fade out
        NSAnimationContext.runAnimationGroup({ [weak self] context in
            context.duration = 0.10
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            context.allowsImplicitAnimation = true
            
            self?.currentAnimationContext = context
            
            // Fade out and slightly scale down
            window.animator().alphaValue = 0
            
            if let contentView = window.contentView {
                contentView.layer?.transform = CATransform3DMakeScale(0.96, 0.96, 1.0)
            }
        }, completionHandler: { [weak self] in
            self?.currentAnimationContext = nil
            // Hide window after animation
            window.orderOut(nil)
        })
    }
    
    func isPaletteVisible() -> Bool {
        return paletteWindow?.isVisible ?? false
    }
    
    func isPaletteFrontmost() -> Bool {
        return paletteWindow?.isKeyWindow ?? false
    }
    
    // MARK: - Onboarding Window
    
    func showOnboardingWindow(with view: some View) {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindow()
        }
        onboardingWindow?.showOnboarding(with: view)
    }
    
    func hideOnboardingWindow() {
        onboardingWindow?.close()
        onboardingWindow = nil
    }
    
    // MARK: - Window Positioning
    
    private func positionWindow(_ window: NSWindow, appSettings: AppSettings) {
        let position = appSettings.position
        
        logDebug(.window, "Position mode: \(position.rawValue)")
        
        switch position {
        case .remember:
            if let savedPosition = loadSavedWindowPosition() {
                window.setFrameOrigin(savedPosition)
                logDebug(.window, "Using saved window position: \(savedPosition)")
            } else {
                logDebug(.window, "No saved position found, using center")
                positionAtCenter(window)
            }
            
        case .center:
            positionAtCenter(window)
            
        case .topCenter:
            positionAtTopCenter(window)
        }
    }
    
    private func positionAtCenter(_ window: NSWindow) {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            let x = (screenFrame.width - windowSize.width) / 2 + screenFrame.origin.x
            let y = (screenFrame.height - windowSize.height) / 2 + screenFrame.origin.y
            window.setFrameOrigin(NSPoint(x: x, y: y))
            logDebug(.window, "Positioned at center")
        }
    }
    
    private func positionAtTopCenter(_ window: NSWindow) {
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowSize = window.frame.size
            let x = (screenFrame.width - windowSize.width) / 2 + screenFrame.origin.x
            let y = screenFrame.origin.y + screenFrame.height - (screenFrame.height * 0.3) - windowSize.height
            window.setFrameOrigin(NSPoint(x: x, y: y))
            logDebug(.window, "Positioned at top center")
        }
    }
    
    private func saveWindowPosition(_ position: NSPoint) {
        let positionString = NSStringFromPoint(position)
        UserDefaults.standard.set(positionString, forKey: "PaletteWindowPosition")
        logDebug(.window, "Saved window position: \(positionString)")
    }
    
    private func loadSavedWindowPosition() -> NSPoint? {
        guard let positionString = UserDefaults.standard.string(forKey: "PaletteWindowPosition") else {
            return nil
        }
        let position = NSPointFromString(positionString)
        logDebug(.window, "Loaded saved position: \(position)")
        return position
    }
    
    // MARK: - NSWindowDelegate
    
    func windowDidMove(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == paletteWindow else { return }
        
        saveWindowPosition(window.frame.origin)
        delegate?.windowDidMove()
    }
    
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow,
           window == onboardingWindow {
            onboardingWindow = nil
        }
    }
}

@MainActor
protocol WindowControllerDelegate: AnyObject {
    func windowDidMove()
}