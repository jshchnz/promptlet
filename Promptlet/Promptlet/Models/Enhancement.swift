//
//  Enhancement.swift
//  Promptlet
//
//  Created by Josh Cohenzadeh on 8/29/25.
//

import Foundation

enum PlacementMode: String, Codable, CaseIterable {
    case cursor = "Cursor"
    case top = "Top"
    case bottom = "Bottom"
    case wrap = "Wrap"
    
    var symbolName: String {
        switch self {
        case .cursor: return "text.cursor"
        case .top: return "arrow.up.to.line"
        case .bottom: return "arrow.down.to.line"
        case .wrap: return "rectangle.and.text.magnifyingglass"
        }
    }
    
    var description: String {
        switch self {
        case .cursor: return "Insert at cursor position"
        case .top: return "Insert at top of field"
        case .bottom: return "Insert at bottom of field"
        case .wrap: return "Wrap around selection"
        }
    }
}

enum Transform: String, Codable, CaseIterable {
    case ensureTrailingNewline = "Ensure trailing newline"
    case codeFence = "Code fence"
    case quote = "Quote lines"
    case header = "Add header"
    case timestamp = "Add timestamp"
    
    var symbolName: String {
        switch self {
        case .ensureTrailingNewline: return "return"
        case .codeFence: return "chevron.left.forwardslash.chevron.right"
        case .quote: return "quote.opening"
        case .header: return "number"
        case .timestamp: return "clock"
        }
    }
}

struct Enhancement: Codable, Hashable {
    var placement: PlacementMode = .cursor
    
    var newlineAfter: Bool = false
    var blankLineAfter: Bool = false
    var newlineBefore: Bool = false
    var blankLineBefore: Bool = false
    
    var wrapPrefix: String = ""
    var wrapSuffix: String = ""
    var codeFenceLanguage: String = ""
    
    var transforms: Set<Transform> = []
    
    var headerLevel: Int = 1
    var timestampFormat: String = "ISO8601"
    
    init(
        placement: PlacementMode = .cursor,
        newlineAfter: Bool = false,
        blankLineAfter: Bool = false,
        newlineBefore: Bool = false,
        blankLineBefore: Bool = false,
        wrapPrefix: String = "",
        wrapSuffix: String = "",
        codeFenceLanguage: String = "",
        transforms: Set<Transform> = [],
        headerLevel: Int = 1,
        timestampFormat: String = "ISO8601"
    ) {
        self.placement = placement
        self.newlineAfter = newlineAfter
        self.blankLineAfter = blankLineAfter
        self.newlineBefore = newlineBefore
        self.blankLineBefore = blankLineBefore
        self.wrapPrefix = wrapPrefix
        self.wrapSuffix = wrapSuffix
        self.codeFenceLanguage = codeFenceLanguage
        self.transforms = transforms
        self.headerLevel = headerLevel
        self.timestampFormat = timestampFormat
        
        logDebug(.prompt, "Enhancement created with placement: \(placement.rawValue), transforms: \(transforms.map { $0.rawValue })")
    }
    
    func apply(to content: String, with selection: String? = nil, existingContent: String = "") -> String {
        var result = content
        
        if transforms.contains(.timestamp) {
            let timestamp = formatTimestamp()
            result = result.replacingOccurrences(of: "{{timestamp}}", with: timestamp)
        }
        
        if transforms.contains(.header) {
            let headerPrefix = String(repeating: "#", count: headerLevel) + " "
            result = headerPrefix + result
        }
        
        if transforms.contains(.quote) {
            let lines = result.split(separator: "\n", omittingEmptySubsequences: false)
            result = lines.map { "> " + $0 }.joined(separator: "\n")
        }
        
        switch placement {
        case .cursor:
            return result
            
        case .top:
            var parts: [String] = []
            parts.append(result)
            if newlineAfter { parts.append("") }
            if blankLineAfter { parts.append("") }
            parts.append(existingContent)
            return parts.joined(separator: "\n")
            
        case .bottom:
            var parts: [String] = []
            parts.append(existingContent)
            if newlineBefore { parts.append("") }
            if blankLineBefore { parts.append("") }
            parts.append(result)
            return parts.joined(separator: "\n")
            
        case .wrap:
            if let selection = selection, !selection.isEmpty {
                var wrapped = selection
                
                if transforms.contains(.codeFence) && !codeFenceLanguage.isEmpty {
                    wrapped = "```\(codeFenceLanguage)\n\(selection)\n```"
                } else if !wrapPrefix.isEmpty || !wrapSuffix.isEmpty {
                    wrapped = wrapPrefix + selection + wrapSuffix
                }
                
                return result.replacingOccurrences(of: "{{selection}}", with: wrapped)
            }
            return result
        }
    }
    
    private func formatTimestamp() -> String {
        let formatter = DateFormatter()
        
        switch timestampFormat {
        case "ISO8601":
            formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        case "Short":
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        case "Medium":
            formatter.dateStyle = .medium
            formatter.timeStyle = .medium
        case "Long":
            formatter.dateStyle = .long
            formatter.timeStyle = .long
        default:
            formatter.dateFormat = timestampFormat
        }
        
        return formatter.string(from: Date())
    }
    
    var requiresSelection: Bool {
        placement == .wrap && (!wrapPrefix.isEmpty || !wrapSuffix.isEmpty)
    }
}

extension Enhancement {
    static let cursorDefault = Enhancement(placement: .cursor)
    static let topWithSpace = Enhancement(placement: .top, newlineAfter: true)
    static let bottomWithSpace = Enhancement(placement: .bottom, newlineBefore: true)
    static let markdownCodeWrap = Enhancement(
        placement: .wrap,
        wrapPrefix: "```\n",
        wrapSuffix: "\n```",
        transforms: [.codeFence]
    )
}