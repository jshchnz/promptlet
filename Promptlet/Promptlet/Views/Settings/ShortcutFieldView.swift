//
//  ShortcutFieldView.swift
//  Promptlet
//
//  Created by Assistant on 8/31/25.
//

import SwiftUI
import AppKit

struct ShortcutFieldView: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut?
    let isRequired: Bool
    
    func makeNSView(context: Context) -> ShortcutFieldNSView {
        let view = ShortcutFieldNSView()
        view.shortcut = shortcut
        view.isRequired = isRequired
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: ShortcutFieldNSView, context: Context) {
        nsView.shortcut = shortcut
        nsView.isRequired = isRequired
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ShortcutFieldDelegate {
        var parent: ShortcutFieldView
        
        init(_ parent: ShortcutFieldView) {
            self.parent = parent
        }
        
        func shortcutDidChange(_ shortcut: KeyboardShortcut?) {
            parent.shortcut = shortcut
        }
    }
}

protocol ShortcutFieldDelegate: AnyObject {
    func shortcutDidChange(_ shortcut: KeyboardShortcut?)
}

class ShortcutFieldNSView: NSView {
    weak var delegate: ShortcutFieldDelegate?
    var isRequired = false
    
    var shortcut: KeyboardShortcut? {
        didSet {
            updateDisplay()
        }
    }
    
    private var isRecording = false {
        didSet {
            updateDisplay()
            if isRecording {
                window?.makeFirstResponder(self)
            }
        }
    }
    
    private let textField = NSTextField()
    private let clearButton = NSButton()
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }
    
    private func setupViews() {
        // Setup text field
        textField.isEditable = false
        textField.isSelectable = false
        textField.isBordered = true
        textField.bezelStyle = .roundedBezel
        textField.alignment = .center
        textField.font = .monospacedSystemFont(ofSize: NSFont.systemFontSize, weight: .regular)
        textField.translatesAutoresizingMaskIntoConstraints = false
        addSubview(textField)
        
        // Setup clear button
        clearButton.bezelStyle = .inline
        clearButton.image = NSImage(systemSymbolName: "xmark.circle.fill", accessibilityDescription: "Clear")
        clearButton.imagePosition = .imageOnly
        clearButton.isBordered = false
        clearButton.target = self
        clearButton.action = #selector(clearShortcut)
        clearButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(clearButton)
        
        // Layout constraints
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: leadingAnchor),
            textField.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),
            textField.topAnchor.constraint(equalTo: topAnchor),
            textField.bottomAnchor.constraint(equalTo: bottomAnchor),
            
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            clearButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            clearButton.widthAnchor.constraint(equalToConstant: 20)
        ])
        
        // Add click gesture
        let clickGesture = NSClickGestureRecognizer(target: self, action: #selector(handleClick))
        textField.addGestureRecognizer(clickGesture)
        
        updateDisplay()
    }
    
    private func updateDisplay() {
        if isRecording {
            textField.stringValue = "Press keys..."
            textField.textColor = .controlAccentColor
        } else if let shortcut = shortcut {
            textField.stringValue = shortcut.displayString
            textField.textColor = .labelColor
        } else {
            textField.stringValue = "–"
            textField.textColor = .secondaryLabelColor
        }
        
        clearButton.isHidden = shortcut == nil || isRequired || isRecording
    }
    
    @objc private func handleClick() {
        isRecording = !isRecording
    }
    
    @objc private func clearShortcut() {
        shortcut = nil
        delegate?.shortcutDidChange(nil)
    }
    
    override var acceptsFirstResponder: Bool {
        return isRecording
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        
        // Check for escape to cancel
        if event.keyCode == 53 && event.modifierFlags.intersection([.command, .option, .control, .shift]).isEmpty {
            isRecording = false
            return
        }
        
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let flags = event.modifierFlags.intersection(relevantFlags)
        
        // Allow certain keys without modifiers
        let allowedWithoutModifiers: [UInt16] = [
            125, 126, 123, 124,  // Arrow keys
            18, 19, 20, 21, 22, 23, 26, 28, 25,  // Numbers 1-9
            36,  // Return
            53,  // Escape
            48,  // Tab
            51,  // Delete
        ]
        
        if !flags.isEmpty || allowedWithoutModifiers.contains(event.keyCode) {
            let newShortcut = KeyboardShortcut(
                keyCode: event.keyCode,
                modifierFlags: flags.rawValue
            )
            shortcut = newShortcut
            delegate?.shortcutDidChange(newShortcut)
            isRecording = false
        }
    }
    
    override func resignFirstResponder() -> Bool {
        isRecording = false
        return true
    }
}