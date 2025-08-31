//
//  SettingsView.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        TabView {
            GeneralSettingsTab(settings: settings)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }
                .tag(0)
            
            KeyboardSettingsTab(settings: settings)
                .tabItem {
                    Label("Keyboard", systemImage: "keyboard")
                }
                .tag(1)
            
            AppearanceSettingsTab(settings: settings)
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(2)
        }
        .frame(width: 680, height: 420)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var showResetConfirmation = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    LabeledContent("Position:") {
                        Picker("", selection: $settings.defaultPosition) {
                            ForEach(DefaultPosition.allCases, id: \.rawValue) { position in
                                Text(position.rawValue).tag(position.rawValue)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }
                    
                    Text("Choose where the palette window appears when opened")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    
                    if settings.savedWindowPosition != nil {
                        HStack {
                            Text("Custom position saved")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                            
                            Button("Clear") {
                                showResetConfirmation = true
                            }
                            .controlSize(.small)
                        }
                    }
                }
                .padding(4)
            } label: {
                Label("Palette Window", systemImage: "rectangle.stack")
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding()
        .alert("Clear Saved Position", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                settings.resetWindowPosition()
            }
        } message: {
            Text("The palette will return to the default position next time it opens.")
        }
    }
}

// MARK: - Keyboard Tab

struct KeyboardSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @State private var selectedCategory = "Global"
    @State private var showResetConfirmation = false
    
    let categories = [
        ("Global", "globe", [ShortcutAction.showPalette]),
        ("Navigation", "arrow.up.arrow.down", [ShortcutAction.navigateUp, .navigateDown, .closePalette]),
        ("Actions", "command", [ShortcutAction.insertPrompt, .newPrompt]),
        ("Quick Slots", "number.square", [ShortcutAction.quickSlot1, .quickSlot2, .quickSlot3, .quickSlot4, .quickSlot5, .quickSlot6, .quickSlot7, .quickSlot8, .quickSlot9])
    ]
    
    var body: some View {
        HSplitView {
            // Sidebar
            List(selection: $selectedCategory) {
                ForEach(categories, id: \.0) { category, icon, _ in
                    Label(category, systemImage: icon)
                        .tag(category)
                }
            }
            .listStyle(.sidebar)
            .frame(width: 150)
            
            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if let category = categories.first(where: { $0.0 == selectedCategory }) {
                        ForEach(category.2, id: \.self) { action in
                            ShortcutRow(action: action, settings: settings)
                            
                            if action != category.2.last {
                                Divider()
                                    .padding(.vertical, 8)
                            }
                        }
                    }
                    
                    Spacer(minLength: 20)
                    
                    HStack {
                        Spacer()
                        Button("Restore Defaults") {
                            showResetConfirmation = true
                        }
                        .controlSize(.regular)
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .alert("Restore Default Shortcuts", isPresented: $showResetConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Restore", role: .destructive) {
                settings.resetShortcutsToDefault()
                NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
            }
        } message: {
            Text("This will restore all keyboard shortcuts to their default values.")
        }
    }
}

struct ShortcutRow: View {
    let action: ShortcutAction
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(action.displayName)
                    .font(.system(.body))
                
                if let description = getDescription(for: action) {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            NativeShortcutField(
                shortcut: Binding(
                    get: { settings.getShortcut(for: action) },
                    set: { newShortcut in
                        settings.updateShortcut(for: action, shortcut: newShortcut)
                        NotificationCenter.default.post(name: .shortcutsChanged, object: nil)
                    }
                ),
                isRequired: action == .showPalette
            )
            .frame(width: 140)
        }
    }
    
    func getDescription(for action: ShortcutAction) -> String? {
        switch action {
        case .showPalette:
            return "Opens the prompt palette from anywhere"
        case .navigateUp, .navigateDown:
            return nil
        case .closePalette:
            return "Closes the palette without inserting"
        case .insertPrompt:
            return "Inserts the selected prompt"
        case .newPrompt:
            return "Creates a new prompt"
        case .quickSlot1, .quickSlot2, .quickSlot3, .quickSlot4, .quickSlot5, .quickSlot6, .quickSlot7, .quickSlot8, .quickSlot9:
            return "Instantly insert this quick slot prompt"
        }
    }
}

// MARK: - Native Shortcut Field

struct NativeShortcutField: NSViewRepresentable {
    @Binding var shortcut: KeyboardShortcut?
    let isRequired: Bool
    
    func makeNSView(context: Context) -> ShortcutFieldView {
        let view = ShortcutFieldView()
        view.shortcut = shortcut
        view.isRequired = isRequired
        view.delegate = context.coordinator
        return view
    }
    
    func updateNSView(_ nsView: ShortcutFieldView, context: Context) {
        nsView.shortcut = shortcut
        nsView.isRequired = isRequired
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, ShortcutFieldDelegate {
        var parent: NativeShortcutField
        
        init(_ parent: NativeShortcutField) {
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

class ShortcutFieldView: NSView {
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

// MARK: - Appearance Tab

struct AppearanceSettingsTab: View {
    @ObservedObject var settings: AppSettings
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            GroupBox {
                VStack(alignment: .leading, spacing: 16) {
                    LabeledContent("Appearance:") {
                        Picker("", selection: $settings.themeMode) {
                            ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                                Text(mode.rawValue).tag(mode.rawValue)
                            }
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 250)
                    }
                    
                    Text("Promptlet automatically adjusts to match your system appearance")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(4)
            } label: {
                Label("Theme", systemImage: "circle.lefthalf.filled")
                    .font(.headline)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    SettingsView(settings: AppSettings())
}