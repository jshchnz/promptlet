//
//  Variable.swift
//  Promptlet
//
//  Created by Josh Cohenzadeh on 8/29/25.
//

import Foundation

enum VariableType: String, Codable {
    case text
    case date
    case time
    case selection
    case clipboard
    case choice
    
    var symbolName: String {
        switch self {
        case .text: return "text.cursor"
        case .date: return "calendar"
        case .time: return "clock"
        case .selection: return "selection.pin.in.out"
        case .clipboard: return "doc.on.clipboard"
        case .choice: return "list.bullet"
        }
    }
}

struct Variable: Identifiable, Codable, Hashable {
    let id: UUID
    let name: String
    let type: VariableType
    var defaultValue: String?
    var lastValue: String?
    var choices: [String]?
    var rememberValue: Bool
    
    init(
        id: UUID = UUID(),
        name: String,
        type: VariableType = .text,
        defaultValue: String? = nil,
        lastValue: String? = nil,
        choices: [String]? = nil,
        rememberValue: Bool = false
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.defaultValue = defaultValue
        self.lastValue = lastValue
        self.choices = choices
        self.rememberValue = rememberValue
        
        print("[Variable] Created: \(name) of type \(type.rawValue)")
    }
    
    static func extractVariables(from content: String) -> [Variable] {
        var variables: [Variable] = []
        var processedNames = Set<String>()
        
        let pattern = #"\{\{(\w+)(?:\|([^}]+))?\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return variables
        }
        
        let matches = regex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
        
        for match in matches {
            if let nameRange = Range(match.range(at: 1), in: content) {
                let name = String(content[nameRange])
                
                guard !processedNames.contains(name) else { continue }
                processedNames.insert(name)
                
                let type = determineType(for: name)
                guard !isBuiltIn(name) else { continue }
                
                var choices: [String]? = nil
                if match.numberOfRanges > 2,
                   let choicesRange = Range(match.range(at: 2), in: content) {
                    let choicesString = String(content[choicesRange])
                    choices = choicesString.split(separator: "|").map { String($0.trimmingCharacters(in: .whitespaces)) }
                }
                
                let variable = Variable(
                    name: name,
                    type: choices != nil ? .choice : type,
                    choices: choices
                )
                variables.append(variable)
                
                print("[Variable] Extracted: \(name) with type \(variable.type.rawValue)")
            }
        }
        
        let allCapsPattern = #"\b[A-Z_]+\b"#
        if let allCapsRegex = try? NSRegularExpression(pattern: allCapsPattern, options: []) {
            let allCapsMatches = allCapsRegex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
            for match in allCapsMatches {
                if let range = Range(match.range, in: content) {
                    let token = String(content[range])
                    if !processedNames.contains(token) && token.count > 2 {
                        print("[Variable] Found potential ALL_CAPS variable: \(token)")
                    }
                }
            }
        }
        
        let bracketPattern = #"\[([^\]]+)\]"#
        if let bracketRegex = try? NSRegularExpression(pattern: bracketPattern, options: []) {
            let bracketMatches = bracketRegex.matches(in: content, options: [], range: NSRange(content.startIndex..., in: content))
            for match in bracketMatches {
                if let range = Range(match.range(at: 1), in: content) {
                    let token = String(content[range])
                    if !processedNames.contains(token) && token.count > 2 {
                        print("[Variable] Found potential [bracket] variable: \(token)")
                    }
                }
            }
        }
        
        return variables
    }
    
    private static func determineType(for name: String) -> VariableType {
        let lowercased = name.lowercased()
        
        if lowercased.contains("date") || lowercased == "today" || lowercased == "tomorrow" {
            return .date
        } else if lowercased.contains("time") || lowercased == "now" {
            return .time
        } else if lowercased == "selection" || lowercased.contains("selected") {
            return .selection
        } else if lowercased == "clipboard" || lowercased.contains("paste") {
            return .clipboard
        }
        
        return .text
    }
    
    private static func isBuiltIn(_ name: String) -> Bool {
        let builtIns = ["date", "time", "selection", "clipboard", "timestamp"]
        return builtIns.contains(name.lowercased())
    }
    
    func currentValue() -> String {
        switch type {
        case .date:
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: Date())
            
        case .time:
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: Date())
            
        case .selection:
            return "[Current Selection]"
            
        case .clipboard:
            return "[Clipboard Content]"
            
        case .text, .choice:
            return lastValue ?? defaultValue ?? ""
        }
    }
    
    mutating func updateLastValue(_ value: String) {
        if rememberValue {
            lastValue = value
            print("[Variable] Updated last value for \(name): \(value)")
        }
    }
}