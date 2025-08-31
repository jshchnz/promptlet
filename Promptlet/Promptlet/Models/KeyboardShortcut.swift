//
//  KeyboardShortcut.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import AppKit

enum ShortcutAction: String, CaseIterable, Codable {
    // Global
    case showPalette = "show_palette"
    
    // Palette Navigation
    case navigateUp = "navigate_up"
    case navigateDown = "navigate_down"
    case closePalette = "close_palette"
    
    // Palette Actions
    case insertPrompt = "insert_prompt"
    case newPrompt = "new_prompt"
    
    // Quick Slots
    case quickSlot1 = "quick_slot_1"
    case quickSlot2 = "quick_slot_2"
    case quickSlot3 = "quick_slot_3"
    case quickSlot4 = "quick_slot_4"
    case quickSlot5 = "quick_slot_5"
    case quickSlot6 = "quick_slot_6"
    case quickSlot7 = "quick_slot_7"
    case quickSlot8 = "quick_slot_8"
    case quickSlot9 = "quick_slot_9"
    
    var displayName: String {
        switch self {
        case .showPalette: return "Show Palette"
        case .navigateUp: return "Navigate Up"
        case .navigateDown: return "Navigate Down"
        case .closePalette: return "Close Palette"
        case .insertPrompt: return "Insert Prompt"
        case .newPrompt: return "New Prompt"
        case .quickSlot1: return "Quick Slot 1"
        case .quickSlot2: return "Quick Slot 2"
        case .quickSlot3: return "Quick Slot 3"
        case .quickSlot4: return "Quick Slot 4"
        case .quickSlot5: return "Quick Slot 5"
        case .quickSlot6: return "Quick Slot 6"
        case .quickSlot7: return "Quick Slot 7"
        case .quickSlot8: return "Quick Slot 8"
        case .quickSlot9: return "Quick Slot 9"
        }
    }
    
    var category: String {
        switch self {
        case .showPalette: return "Global"
        case .navigateUp, .navigateDown, .closePalette: return "Palette Navigation"
        case .insertPrompt, .newPrompt: return "Palette Actions"
        case .quickSlot1, .quickSlot2, .quickSlot3, .quickSlot4, .quickSlot5,
             .quickSlot6, .quickSlot7, .quickSlot8, .quickSlot9: return "Quick Slots"
        }
    }
}

struct KeyboardShortcut: Codable, Equatable, Identifiable {
    let id = UUID()
    let keyCode: UInt16
    let modifierFlags: UInt
    
    // Computed property for display string
    var displayString: String {
        var parts: [String] = []
        
        let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
        
        if flags.contains(.control) {
            parts.append("⌃")
        }
        if flags.contains(.option) {
            parts.append("⌥")
        }
        if flags.contains(.shift) {
            parts.append("⇧")
        }
        if flags.contains(.command) {
            parts.append("⌘")
        }
        
        parts.append(keyStringFromKeyCode(keyCode))
        
        return parts.joined()
    }
    
    // Check if this shortcut matches an NSEvent
    func matches(event: NSEvent) -> Bool {
        // Get the relevant modifier flags (ignore caps lock, function key, etc.)
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let eventFlags = event.modifierFlags.intersection(relevantFlags)
        let shortcutFlags = NSEvent.ModifierFlags(rawValue: modifierFlags).intersection(relevantFlags)
        
        return event.keyCode == keyCode && eventFlags == shortcutFlags
    }
    
    // Convert key code to readable string
    private func keyStringFromKeyCode(_ keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 114: return "Help"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "Forward Delete"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "Page Down"
        case 122: return "F1"
        case 123: return "←"
        case 124: return "→"
        case 125: return "↓"
        case 126: return "↑"
        default: return "Key\(keyCode)"
        }
    }
    
    // Coding keys for custom encoding
    enum CodingKeys: String, CodingKey {
        case keyCode
        case modifierFlags
    }
    
    // Default shortcuts dictionary
    static let defaultShortcuts: [ShortcutAction: KeyboardShortcut] = [
        .showPalette: KeyboardShortcut(keyCode: 47, modifierFlags: NSEvent.ModifierFlags.command.rawValue), // Cmd+.
        .navigateUp: KeyboardShortcut(keyCode: 126, modifierFlags: 0), // Up arrow
        .navigateDown: KeyboardShortcut(keyCode: 125, modifierFlags: 0), // Down arrow
        .closePalette: KeyboardShortcut(keyCode: 53, modifierFlags: 0), // Escape
        .insertPrompt: KeyboardShortcut(keyCode: 36, modifierFlags: 0), // Return
        .newPrompt: KeyboardShortcut(keyCode: 45, modifierFlags: NSEvent.ModifierFlags.command.rawValue), // Cmd+N
        .quickSlot1: KeyboardShortcut(keyCode: 18, modifierFlags: 0), // 1
        .quickSlot2: KeyboardShortcut(keyCode: 19, modifierFlags: 0), // 2
        .quickSlot3: KeyboardShortcut(keyCode: 20, modifierFlags: 0), // 3
        .quickSlot4: KeyboardShortcut(keyCode: 21, modifierFlags: 0), // 4
        .quickSlot5: KeyboardShortcut(keyCode: 23, modifierFlags: 0), // 5
        .quickSlot6: KeyboardShortcut(keyCode: 22, modifierFlags: 0), // 6
        .quickSlot7: KeyboardShortcut(keyCode: 26, modifierFlags: 0), // 7
        .quickSlot8: KeyboardShortcut(keyCode: 28, modifierFlags: 0), // 8
        .quickSlot9: KeyboardShortcut(keyCode: 25, modifierFlags: 0), // 9
    ]
    
    // Validate shortcut based on action requirements
    func isValid(for action: ShortcutAction) -> Bool {
        // Global shortcuts require at least one modifier
        if action == .showPalette || action == .newPrompt {
            let flags = NSEvent.ModifierFlags(rawValue: modifierFlags)
            return flags.contains(.command) || flags.contains(.control) || flags.contains(.option)
        }
        // Navigation and quick slots can be modifier-less
        return true
    }
    
    // Create from NSEvent
    static func from(event: NSEvent) -> KeyboardShortcut? {
        let relevantFlags: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let flags = event.modifierFlags.intersection(relevantFlags)
        
        // Require at least one modifier
        guard !flags.isEmpty else { return nil }
        
        return KeyboardShortcut(
            keyCode: event.keyCode,
            modifierFlags: flags.rawValue
        )
    }
}