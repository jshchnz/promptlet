//
//  Prompt.swift
//  Promptlet
//
//  Created by Josh Cohenzadeh on 8/29/25.
//

import Foundation
import SwiftUI

struct Prompt: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var content: String
    var tags: Set<String>
    var category: String?
    var defaultEnhancement: Enhancement
    var variables: [Variable]
    var isFavorite: Bool
    var isArchived: Bool
    var quickSlot: Int?
    var createdDate: Date
    var lastUsedDate: Date
    var usageCount: Int
    var perAppEnhancements: [String: Enhancement]
    var displayOrder: Int
    
    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        tags: Set<String> = [],
        category: String? = nil,
        defaultEnhancement: Enhancement = Enhancement(),
        variables: [Variable] = [],
        isFavorite: Bool = false,
        isArchived: Bool = false,
        quickSlot: Int? = nil,
        createdDate: Date = Date(),
        lastUsedDate: Date = Date(),
        usageCount: Int = 0,
        perAppEnhancements: [String: Enhancement] = [:],
        displayOrder: Int = 0
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.tags = tags
        self.category = category
        self.defaultEnhancement = defaultEnhancement
        self.variables = Variable.extractVariables(from: content)
        self.isFavorite = isFavorite
        self.isArchived = isArchived
        self.quickSlot = quickSlot
        self.createdDate = createdDate
        self.lastUsedDate = lastUsedDate
        self.usageCount = usageCount
        self.perAppEnhancements = perAppEnhancements
        self.displayOrder = displayOrder
        
        logDebug(.prompt, "Created: \(title) with \(self.variables.count) variables")
    }
    
    var preview: String {
        let lines = content.split(separator: "\n", maxSplits: 1)
        return String(lines.first ?? "")
    }
    
    func renderedContent(with values: [String: String]) -> String {
        var result = content
        
        for variable in variables {
            if let value = values[variable.name] ?? variable.lastValue {
                let placeholder = "{{\(variable.name)}}"
                result = result.replacingOccurrences(of: placeholder, with: value)
                logDebug(.prompt, "Replaced \(placeholder) with: \(value)")
            }
        }
        
        if let clipboard = values["clipboard"] {
            result = result.replacingOccurrences(of: "{{clipboard}}", with: clipboard)
        }
        
        if let selection = values["selection"] {
            result = result.replacingOccurrences(of: "{{selection}}", with: selection)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        result = result.replacingOccurrences(of: "{{date}}", with: dateFormatter.string(from: Date()))
        
        dateFormatter.dateStyle = .none
        dateFormatter.timeStyle = .short
        result = result.replacingOccurrences(of: "{{time}}", with: dateFormatter.string(from: Date()))
        
        return result
    }
    
    mutating func recordUsage() {
        usageCount += 1
        lastUsedDate = Date()
        logDebug(.prompt, "Used: \(title), count: \(usageCount)")
    }
    
    var frecencyScore: Double {
        let timeSinceLastUse = Date().timeIntervalSince(lastUsedDate)
        let hoursAgo = timeSinceLastUse / 3600
        let recencyScore = max(0, 100 - hoursAgo)
        let frequencyScore = Double(usageCount) * 10
        return recencyScore + frequencyScore
    }
}

extension Prompt {
    static let samplePrompts: [Prompt] = [
        // Claude Code optimized prompt enhancements
        Prompt(
            title: "Ultrathink",
            content: "Ultrathink.",
            tags: ["deep-thinking", "claude-code"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 0
        ),
        Prompt(
            title: "Step-by-Step",
            content: "Think step-by-step through this problem.",
            tags: ["reasoning", "systematic"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 1
        ),
        Prompt(
            title: "Deep Analysis",
            content: "Think harder about this. What am I missing?",
            tags: ["analysis", "deep-thinking"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 2
        ),
        Prompt(
            title: "Systematic Debug",
            content: "Debug this systematically. Find the root cause, not just symptoms.",
            tags: ["debugging", "troubleshooting"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 3
        ),
        Prompt(
            title: "Senior Review",
            content: "Review this code as a senior engineer would. Be critical but constructive.",
            tags: ["code-review", "quality"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 4
        ),
        Prompt(
            title: "Edge Cases",
            content: "What edge cases, failure modes, and corner cases should I consider?",
            tags: ["testing", "risk-analysis"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 5
        ),
        Prompt(
            title: "Explain First",
            content: "First explain your reasoning and approach, then implement the solution.",
            tags: ["planning", "documentation"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 6
        ),
        Prompt(
            title: "Performance Focus",
            content: "Analyze performance bottlenecks. Profile first, then optimize strategically.",
            tags: ["performance", "optimization"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 7
        ),
        Prompt(
            title: "Security Audit",
            content: "Security audit: Find vulnerabilities, attack vectors, and potential exploits.",
            tags: ["security", "audit"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 8
        ),
        Prompt(
            title: "Test First",
            content: "Write comprehensive tests first (TDD), then implement to make them pass.",
            tags: ["testing", "tdd"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 9
        ),
        Prompt(
            title: "Architecture Mode",
            content: "<architecture>Design the system architecture before writing any code. Consider scalability, maintainability, and trade-offs.</architecture>",
            tags: ["architecture", "design"],
            defaultEnhancement: Enhancement(placement: .cursor),
            displayOrder: 10
        )
    ]
}