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
        
        logDebug(.prompt, "Variable created: \(name) of type \(type.rawValue)")
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
            if let variable = extractVariable(from: match, in: content, processedNames: &processedNames) {
                variables.append(variable)
            }
        }
        
        return variables
    }
    
    private static func extractVariable(from match: NSTextCheckingResult, in content: String, processedNames: inout Set<String>) -> Variable? {
        guard let nameRange = Range(match.range(at: 1), in: content) else { return nil }
        
        let name = String(content[nameRange])
        
        guard !processedNames.contains(name) else { return nil }
        processedNames.insert(name)
        
        guard !isBuiltIn(name) else { return nil }
        
        let choices = extractChoices(from: match, in: content)
        let type = choices != nil ? .choice : determineType(for: name)
        
        let variable = Variable(
            name: name,
            type: type,
            choices: choices
        )
        
        logDebug(.prompt, "Variable extracted: \(name) with type \(variable.type.rawValue)")
        return variable
    }
    
    private static func extractChoices(from match: NSTextCheckingResult, in content: String) -> [String]? {
        guard match.numberOfRanges > 2,
              let choicesRange = Range(match.range(at: 2), in: content) else {
            return nil
        }
        
        let choicesString = String(content[choicesRange])
        return choicesString.split(separator: "|").map { String($0.trimmingCharacters(in: .whitespaces)) }
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
            logDebug(.prompt, "Variable updated last value for \(name): \(value)")
        }
    }
}