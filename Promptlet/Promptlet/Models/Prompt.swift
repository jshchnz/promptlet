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
        perAppEnhancements: [String: Enhancement] = [:]
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
        // Simple prompts without variables (most common use case)
        Prompt(
            title: "Ultrathink",
            content: "Ultrathink about this",
            tags: ["thinking", "ai"],
            defaultEnhancement: Enhancement(placement: .cursor)
        ),
        Prompt(
            title: "TODO",
            content: "TODO: ",
            tags: ["code", "task"],
            defaultEnhancement: Enhancement(placement: .cursor)
        ),
        Prompt(
            title: "FIXED",
            content: "FIXED: ",
            tags: ["code", "task"],
            defaultEnhancement: Enhancement(placement: .cursor)
        ),
        Prompt(
            title: "Comment",
            content: "// ",
            tags: ["code"],
            defaultEnhancement: Enhancement(placement: .cursor)
        ),
        Prompt(
            title: "Note",
            content: "NOTE: ",
            tags: ["documentation"],
            defaultEnhancement: Enhancement(placement: .cursor)
        ),
        Prompt(
            title: "Important",
            content: "⚠️ IMPORTANT: ",
            tags: ["documentation", "warning"],
            defaultEnhancement: Enhancement(placement: .cursor)
        ),
        Prompt(
            title: "Question",
            content: "❓ Question: ",
            tags: ["review"],
            defaultEnhancement: Enhancement(placement: .cursor)
        ),
        Prompt(
            title: "Divider",
            content: "---",
            tags: ["markdown"],
            defaultEnhancement: Enhancement(placement: .cursor, newlineAfter: true, newlineBefore: true)
        ),
        // More complex prompts with variables
        Prompt(
            title: "Meeting Notes Header",
            content: "## Meeting Notes - {{date}}\n**Attendees:** {{attendees}}\n**Topic:** {{topic}}\n\n### Agenda\n- \n\n### Action Items\n- ",
            tags: ["meeting", "notes"],
            defaultEnhancement: Enhancement(placement: .top, newlineAfter: true, blankLineAfter: true)
        ),
        Prompt(
            title: "PR Template",
            content: "## Summary\n{{summary}}\n\n## Changes\n- \n\n## Testing\n- [ ] Unit tests pass\n- [ ] Manual testing complete\n\n## Screenshots\n_If applicable_",
            tags: ["github", "pr"],
            defaultEnhancement: Enhancement(placement: .cursor)
        ),
        Prompt(
            title: "Code Fence",
            content: "```{{language}}\n{{selection}}\n```",
            tags: ["markdown", "code"],
            defaultEnhancement: Enhancement(placement: .wrap, wrapPrefix: "```\n", wrapSuffix: "\n```")
        ),
        Prompt(
            title: "Quote Block",
            content: "> {{selection}}",
            tags: ["markdown", "quote"],
            defaultEnhancement: Enhancement(placement: .wrap, transforms: [.quote])
        )
    ]
}