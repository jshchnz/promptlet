//
//  ShortcutRecorderView.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import SwiftUI
import AppKit

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut?
    var onRecord: ((KeyboardShortcut) -> Void)?
    var onClear: (() -> Void)?
    
    func makeNSView(context: Context) -> ShortcutRecorderNSView {
        let view = ShortcutRecorderNSView()
        view.shortcut = shortcut
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: ShortcutRecorderNSView, context: Context) {
        nsView.shortcut = shortcut
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ShortcutRecorderDelegate {
        var parent: ShortcutRecorderView
        
        init(_ parent: ShortcutRecorderView) {
            self.parent = parent
        }
        
        func shortcutRecorded(_ shortcut: KeyboardShortcut) {
            parent.shortcut = shortcut
            parent.onRecord?(shortcut)
        }
        
        func shortcutCleared() {
            parent.shortcut = nil
            parent.onClear?()
        }
    }
}

protocol ShortcutRecorderDelegate: AnyObject {
    func shortcutRecorded(_ shortcut: KeyboardShortcut)
    func shortcutCleared()
}

class ShortcutRecorderNSView: NSView {
    weak var delegate: ShortcutRecorderDelegate?
    
    var shortcut: KeyboardShortcut? {
        didSet {
            needsDisplay = true
        }
    }
    
    private var isRecording = false {
        didSet {
            needsDisplay = true
        }
    }
    
    private var clearButton: NSButton?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        
        // Add tracking area for mouse events
        let trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw background
        let backgroundColor = isRecording ? NSColor.controlAccentColor.withAlphaComponent(0.1) : NSColor.controlBackgroundColor
        backgroundColor.setFill()
        
        let path = NSBezierPath(roundedRect: bounds, xRadius: 4, yRadius: 4)
        path.fill()
        
        // Draw border
        let borderColor = isRecording ? NSColor.controlAccentColor : NSColor.separatorColor
        borderColor.setStroke()
        path.lineWidth = 1
        path.stroke()
        
        // Draw text
        let text: String
        let textColor: NSColor
        
        if isRecording {
            text = "Press keys..."
            textColor = .controlAccentColor
        } else if let shortcut = shortcut {
            text = shortcut.displayString
            textColor = .labelColor
        } else {
            text = "Click to record"
            textColor = .secondaryLabelColor
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13),
            .foregroundColor: textColor
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        let drawPoint = NSPoint(
            x: 10,
            y: (bounds.height - size.height) / 2
        )
        attributedString.draw(at: drawPoint)
        
        // Draw clear button if there's a shortcut and not recording
        if shortcut != nil && !isRecording {
            let clearText = "×"
            let clearAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let clearString = NSAttributedString(string: clearText, attributes: clearAttributes)
            let clearSize = clearString.size()
            let clearPoint = NSPoint(
                x: bounds.width - clearSize.width - 10,
                y: (bounds.height - clearSize.height) / 2
            )
            clearString.draw(at: clearPoint)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        let clickLocation = convert(event.locationInWindow, from: nil)
        
        // Check if clicking on clear button
        if shortcut != nil && !isRecording {
            let clearButtonRect = NSRect(x: bounds.width - 30, y: 0, width: 30, height: bounds.height)
            if clearButtonRect.contains(clickLocation) {
                delegate?.shortcutCleared()
                return
            }
        }
        
        // Toggle recording
        if !isRecording {
            startRecording()
        } else {
            stopRecording()
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        
        print("[ShortcutRecorder] KeyDown - keyCode: \(event.keyCode), modifiers: \(event.modifierFlags.rawValue)")
        
        // Check for escape to cancel recording (when pressed alone)
        if event.keyCode == 53 && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            stopRecording()
            return
        }
        
        // Get modifier flags
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let flags = event.modifierFlags.intersection(relevantFlags)
        
        print("[ShortcutRecorder] Relevant flags: \(flags.rawValue)")
        
        // Allow certain keys without modifiers (arrows, numbers, special keys)
        let allowedWithoutModifiers: [UInt16] = [
            125, 126, 123, 124,  // Arrow keys
            18, 19, 20, 21, 22, 23, 26, 28, 25,  // Numbers 1-9
            36,  // Return
            53,  // Escape (for close palette)
            48,  // Tab
            51,  // Delete
        ]
        
        if !flags.isEmpty || allowedWithoutModifiers.contains(event.keyCode) {
            // Create shortcut
            let newShortcut = KeyboardShortcut(
                keyCode: event.keyCode,
                modifierFlags: flags.rawValue
            )
            print("[ShortcutRecorder] Recording shortcut: \(newShortcut.displayString)")
            delegate?.shortcutRecorded(newShortcut)
            stopRecording()
        } else {
            print("[ShortcutRecorder] Key not allowed without modifiers, waiting...")
        }
    }
    
    override func flagsChanged(with event: NSEvent) {
        guard isRecording else {
            super.flagsChanged(with: event)
            return
        }
        
        // Optionally handle modifier-only shortcuts (not recommended)
        // For now, we'll require at least one non-modifier key
    }
    
    private func startRecording() {
        isRecording = true
        window?.makeFirstResponder(self)
        // Ensure we can receive key events
        if let window = window {
            window.makeKey()
            NSApp.activate(ignoringOtherApps: false)
        }
    }
    
    private func stopRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func becomeFirstResponder() -> Bool {
        print("[ShortcutRecorder] Becoming first responder")
        return true
    }
    
    override func resignFirstResponder() -> Bool {
        if isRecording {
            stopRecording()
        }
        return true
    }
    
    override func mouseEntered(with event: NSEvent) {
        if !isRecording {
            NSCursor.pointingHand.push()
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        NSCursor.pop()
    }
}