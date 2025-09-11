//
//  ShortcutFieldView.swift
//  Promptlet
//
//  Direct event monitoring approach
//

import SwiftUI
import AppKit

struct ShortcutFieldView: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut?
    let isRequired: Bool
    let placeholderText: String
    
    init(shortcut: Binding<KeyboardShortcut?>, isRequired: Bool = false, placeholderText: String = "–") {
        self._shortcut = shortcut
        self.isRequired = isRequired
        self.placeholderText = placeholderText
    }
    
    func makeNSView(context: Context) -> DirectEventShortcutView {
        let view = DirectEventShortcutView()
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: DirectEventShortcutView, context: Context) {
        nsView.shortcut = shortcut
        nsView.isRequired = isRequired
        nsView.placeholderText = placeholderText
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: DirectEventDelegate {
        var parent: ShortcutFieldView
        
        init(_ parent: ShortcutFieldView) {
            self.parent = parent
        }
        
        func shortcutChanged(_ shortcut: KeyboardShortcut?) {
            parent.shortcut = shortcut
        }
    }
}

protocol DirectEventDelegate: AnyObject {
    func shortcutChanged(_ shortcut: KeyboardShortcut?)
}

enum RecordingState {
    case idle
    case recording
    case finalizing
}

class DirectEventShortcutView: NSView {
    weak var delegate: DirectEventDelegate?
    var isRequired = false
    var placeholderText = "–"
    
    var shortcut: KeyboardShortcut? {
        didSet { needsDisplay = true }
    }
    
    private var isRecording: Bool {
        return recordingState != .idle
    }
    
    private var eventTap: CFMachPort?
    private var recordingState: RecordingState = .idle
    private var pressedModifiers: NSEvent.ModifierFlags = []
    private var pressedKey: UInt16?
    private var keyPressModifiers: NSEvent.ModifierFlags = []
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    deinit {
        stopEventTap()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = NSColor.separatorColor.cgColor
        layer?.borderWidth = 1
        layer?.cornerRadius = 6
    }
    
    private func startEventTap() {
        print("Starting CGEventTap for system-level key capture")
        
        // Request accessibility permissions if needed
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as NSString: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options)
        
        if !accessEnabled {
            print("Accessibility access required for system-level key capture")
            return
        }
        
        // Create event tap to capture keyDown, keyUp, and flagsChanged events
        let eventTypes: CGEventMask = (1 << CGEventType.keyDown.rawValue) | 
                                     (1 << CGEventType.keyUp.rawValue) | 
                                     (1 << CGEventType.flagsChanged.rawValue)
        
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventTypes,
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                let shortcutView = Unmanaged<DirectEventShortcutView>.fromOpaque(refcon!).takeUnretainedValue()
                return shortcutView.handleCGEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        )
        
        if let tap = eventTap {
            let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("CGEventTap enabled successfully")
        } else {
            print("Failed to create CGEventTap")
        }
    }
    
    private func handleCGEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Only handle events when recording
        guard recordingState != .idle else {
            return Unmanaged.passRetained(event)
        }
        
        print("CGEvent: type=\(type.rawValue), keyCode=\(event.getIntegerValueField(.keyboardEventKeycode))")
        
        switch type {
        case .keyDown:
            return handleKeyDown(event: event)
        case .keyUp:
            return handleKeyUp(event: event)
        case .flagsChanged:
            return handleFlagsChanged(event: event)
        default:
            return Unmanaged.passRetained(event)
        }
    }
    
    private func handleKeyDown(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        
        // Cancel on escape
        if keyCode == 53 && pressedModifiers.isEmpty {
            DispatchQueue.main.async {
                self.stopRecording()
            }
            return nil // Consume the event
        }
        
        // Skip pure modifier keys
        let modifierKeyCodes: Set<UInt16> = [54, 55, 56, 57, 58, 59, 61, 62]
        if modifierKeyCodes.contains(keyCode) {
            return nil // Consume but don't process
        }
        
        // Record the key and current modifiers, then move to finalizing state
        pressedKey = keyCode
        keyPressModifiers = pressedModifiers
        recordingState = .finalizing
        
        print("Key pressed: \(keyCode), modifiers: \(pressedModifiers.rawValue)")
        
        return nil // Consume the event
    }
    
    private func handleKeyUp(event: CGEvent) -> Unmanaged<CGEvent>? {
        let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        
        // If this is our recorded key and we're finalizing, complete the recording
        if recordingState == .finalizing, 
           let recordedKey = pressedKey, 
           keyCode == recordedKey {
            
            let newShortcut = KeyboardShortcut(keyCode: recordedKey, modifierFlags: keyPressModifiers.rawValue)
            
            print("Completed shortcut on key release: \(newShortcut.displayString)")
            
            DispatchQueue.main.async {
                self.stopRecording()
                self.shortcut = newShortcut
                self.delegate?.shortcutChanged(newShortcut)
            }
        }
        
        return nil // Consume the event
    }
    
    private func handleFlagsChanged(event: CGEvent) -> Unmanaged<CGEvent>? {
        let flags = CGEventFlags(rawValue: event.flags.rawValue)
        let relevantModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        
        var newModifiers: NSEvent.ModifierFlags = []
        if flags.contains(.maskCommand) { newModifiers.insert(.command) }
        if flags.contains(.maskAlternate) { newModifiers.insert(.option) }
        if flags.contains(.maskControl) { newModifiers.insert(.control) }
        if flags.contains(.maskShift) { newModifiers.insert(.shift) }
        
        pressedModifiers = newModifiers.intersection(relevantModifiers)
        
        print("Modifiers changed: \(pressedModifiers.rawValue)")
        
        // If we're finalizing and all modifiers are released, complete the shortcut
        if recordingState == .finalizing, 
           pressedModifiers.isEmpty,
           let recordedKey = pressedKey {
            
            let newShortcut = KeyboardShortcut(keyCode: recordedKey, modifierFlags: keyPressModifiers.rawValue)
            
            print("Completed shortcut on modifier release: \(newShortcut.displayString)")
            
            DispatchQueue.main.async {
                self.stopRecording()
                self.shortcut = newShortcut  
                self.delegate?.shortcutChanged(newShortcut)
            }
        }
        
        return nil // Consume the event
    }
    
    private func stopEventTap() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            CFMachPortInvalidate(tap)
            eventTap = nil
            print("Stopped CGEventTap")
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Draw text
        let text: String
        let color: NSColor
        
        if isRecording {
            text = "Press keys..."
            color = .controlAccentColor
            layer?.borderColor = NSColor.controlAccentColor.cgColor
        } else if let shortcut = shortcut {
            text = shortcut.displayString
            color = .labelColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        } else {
            text = placeholderText
            color = .secondaryLabelColor
            layer?.borderColor = NSColor.separatorColor.cgColor
        }
        
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: color
        ]
        
        let attributedString = NSAttributedString(string: text, attributes: attributes)
        let size = attributedString.size()
        let drawPoint = NSPoint(
            x: (bounds.width - size.width) / 2,
            y: (bounds.height - size.height) / 2
        )
        attributedString.draw(at: drawPoint)
        
        // Draw clear button if needed
        if shortcut != nil && !isRequired && !isRecording {
            let clearText = "✕"
            let clearAttributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
            let clearString = NSAttributedString(string: clearText, attributes: clearAttributes)
            let clearPoint = NSPoint(x: bounds.width - 20, y: (bounds.height - 12) / 2)
            clearString.draw(at: clearPoint)
        }
    }
    
    override func mouseDown(with event: NSEvent) {
        print("DirectEventShortcutView mouseDown")
        
        // Check if clicking clear button
        if shortcut != nil && !isRequired && !isRecording {
            let clickPoint = convert(event.locationInWindow, from: nil)
            let clearRect = NSRect(x: bounds.width - 25, y: 0, width: 25, height: bounds.height)
            if clearRect.contains(clickPoint) {
                shortcut = nil
                delegate?.shortcutChanged(nil)
                return
            }
        }
        
        // Start or stop recording
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        print("DirectEventShortcutView startRecording")
        recordingState = .recording
        pressedModifiers = []
        pressedKey = nil
        keyPressModifiers = []
        startEventTap()
        needsDisplay = true
    }
    
    private func stopRecording() {
        print("DirectEventShortcutView stopRecording")
        recordingState = .idle
        pressedModifiers = []
        pressedKey = nil
        keyPressModifiers = []
        stopEventTap()
        needsDisplay = true
    }
}