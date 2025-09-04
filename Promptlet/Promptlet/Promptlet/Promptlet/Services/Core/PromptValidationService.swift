//
//  PromptValidationService.swift
//  Promptlet
//
//  Handles validation logic for prompts and related data
//

import Foundation

@MainActor
class PromptValidationService: ObservableObject {
    
    // MARK: - Prompt Validation
    
    func validatePrompt(_ prompt: Prompt) -> ValidationResult {
        var errors: [ValidationError] = []
        var warnings: [ValidationWarning] = []
        
        // Title validation
        let titleValidation = validateTitle(prompt.title)
        if case .failure(let error) = titleValidation {
            errors.append(error)
        }
        
        // Content validation
        let contentValidation = validateContent(prompt.content)
        if case .warning(let warning) = contentValidation {
            warnings.append(warning)
        }
        
        // Tags validation
        let tagsValidation = validateTags(prompt.tags)
        if case .warning(let warning) = tagsValidation {
            warnings.append(warning)
        }
        
        // Variables validation
        let variablesValidation = validateVariables(prompt.variables)
        if case .failure(let error) = variablesValidation {
            errors.append(error)
        }
        
        // Quick slot validation
        if let quickSlot = prompt.quickSlot {
            let quickSlotValidation = validateQuickSlot(quickSlot)
            if case .failure(let error) = quickSlotValidation {
                errors.append(error)
            }
        }
        
        if errors.isEmpty {
            return .valid(warnings: warnings)
        } else {
            return .invalid(errors: errors, warnings: warnings)
        }
    }
    
    func validateTitle(_ title: String) -> TitleValidationResult {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .failure(.emptyTitle)
        }
        
        if trimmed.count > 100 {
            return .failure(.titleTooLong)
        }
        
        // Check for problematic characters
        let invalidChars = CharacterSet(charactersIn: "\\/:*?\"<>|")
        if trimmed.rangeOfCharacter(from: invalidChars) != nil {
            return .failure(.invalidCharacters)
        }
        
        return .valid
    }
    
    func validateContent(_ content: String) -> ContentValidationResult {
        if content.isEmpty {
            return .warning(.emptyContent)
        }
        
        if content.count > 10000 {
            return .warning(.contentTooLong)
        }
        
        return .valid
    }
    
    func validateTags(_ tags: Set<String>) -> TagValidationResult {
        if tags.count > 20 {
            return .warning(.tooManyTags)
        }
        
        for tag in tags {
            if tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .warning(.emptyTag)
            }
            
            if tag.count > 50 {
                return .warning(.tagTooLong)
            }
        }
        
        return .valid
    }
    
    func validateVariables(_ variables: [Variable]) -> VariableValidationResult {
        var seenNames: Set<String> = []
        
        for variable in variables {
            if seenNames.contains(variable.name) {
                return .failure(.duplicateVariableName(variable.name))
            }
            seenNames.insert(variable.name)
            
            if variable.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .failure(.emptyVariableName)
            }
            
            // Validate variable name format
            if !isValidVariableName(variable.name) {
                return .failure(.invalidVariableName(variable.name))
            }
            
            // Validate choices for choice type variables
            if variable.type == .choice {
                if let choices = variable.choices, choices.isEmpty {
                    return .failure(.emptyChoices(variable.name))
                }
            }
        }
        
        return .valid
    }
    
    func validateQuickSlot(_ slot: Int) -> QuickSlotValidationResult {
        if slot < AppConfig.QuickSlots.minSlot || slot > AppConfig.QuickSlots.maxSlots {
            return .failure(.invalidQuickSlot(slot))
        }
        return .valid
    }
    
    func validateCategory(_ category: String?) -> CategoryValidationResult {
        guard let category = category else { return .valid }
        
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.isEmpty {
            return .failure(.emptyCategory)
        }
        
        if trimmed.count > 50 {
            return .failure(.categoryTooLong)
        }
        
        return .valid
    }
    
    // MARK: - Bulk Validation
    
    func validatePrompts(_ prompts: [Prompt]) -> BulkValidationResult {
        var validPrompts: [Prompt] = []
        var invalidPrompts: [(Prompt, [ValidationError])] = []
        var warnings: [ValidationWarning] = []
        var duplicateIds: Set<UUID> = []
        var duplicateTitles: [String: [Prompt]] = [:]
        
        // Check for duplicate IDs
        var seenIds: Set<UUID> = []
        for prompt in prompts {
            if seenIds.contains(prompt.id) {
                duplicateIds.insert(prompt.id)
            } else {
                seenIds.insert(prompt.id)
            }
        }
        
        // Check for duplicate titles
        for prompt in prompts {
            if duplicateTitles[prompt.title] == nil {
                duplicateTitles[prompt.title] = []
            }
            duplicateTitles[prompt.title]?.append(prompt)
        }
        
        let actualDuplicateTitles = duplicateTitles.filter { $0.value.count > 1 }
        
        // Validate each prompt
        for prompt in prompts {
            let result = validatePrompt(prompt)
            switch result {
            case .valid(let promptWarnings):
                validPrompts.append(prompt)
                warnings.append(contentsOf: promptWarnings)
            case .invalid(let errors, let promptWarnings):
                invalidPrompts.append((prompt, errors))
                warnings.append(contentsOf: promptWarnings)
            }
        }
        
        // Add duplicate warnings
        if !duplicateIds.isEmpty {
            warnings.append(.duplicateIds(Array(duplicateIds)))
        }
        
        if !actualDuplicateTitles.isEmpty {
            warnings.append(.duplicateTitles(Array(actualDuplicateTitles.keys)))
        }
        
        return BulkValidationResult(
            validPrompts: validPrompts,
            invalidPrompts: invalidPrompts,
            warnings: warnings
        )
    }
    
    // MARK: - Helper Methods
    
    private func isValidVariableName(_ name: String) -> Bool {
        // Variable names should contain only alphanumeric characters and underscores
        let allowedChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        let nameChars = CharacterSet(charactersIn: name)
        return allowedChars.isSuperset(of: nameChars) && !name.isEmpty
    }
    
    // MARK: - Quick Validation Helpers
    
    func canAddPrompt(_ prompt: Prompt, to existingPrompts: [Prompt]) -> Bool {
        // Check for duplicate ID
        if existingPrompts.contains(where: { $0.id == prompt.id }) {
            return false
        }
        
        // Validate the prompt itself
        let validation = validatePrompt(prompt)
        switch validation {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    func canUpdatePrompt(_ prompt: Prompt) -> Bool {
        let validation = validatePrompt(prompt)
        switch validation {
        case .valid:
            return true
        case .invalid:
            return false
        }
    }
    
    func sanitizePrompt(_ prompt: Prompt) -> Prompt {
        var sanitized = prompt
        
        // Sanitize title
        sanitized.title = prompt.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.title.isEmpty {
            sanitized.title = TextConstants.defaultPromptTitle
        }
        
        // Sanitize tags
        sanitized.tags = Set(prompt.tags.compactMap { tag in
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        })
        
        // Sanitize category
        if let category = prompt.category {
            let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
            sanitized.category = trimmed.isEmpty ? nil : trimmed
        }
        
        return sanitized
    }
}

// MARK: - Validation Result Types

enum ValidationResult {
    case valid(warnings: [ValidationWarning])
    case invalid(errors: [ValidationError], warnings: [ValidationWarning])
}

enum TitleValidationResult {
    case valid
    case failure(ValidationError)
}

enum ContentValidationResult {
    case valid
    case warning(ValidationWarning)
}

enum TagValidationResult {
    case valid
    case warning(ValidationWarning)
}

enum VariableValidationResult {
    case valid
    case failure(ValidationError)
}

enum QuickSlotValidationResult {
    case valid
    case failure(ValidationError)
}

enum CategoryValidationResult {
    case valid
    case failure(ValidationError)
}

struct BulkValidationResult {
    let validPrompts: [Prompt]
    let invalidPrompts: [(Prompt, [ValidationError])]
    let warnings: [ValidationWarning]
    
    var isValid: Bool {
        invalidPrompts.isEmpty
    }
    
    var hasWarnings: Bool {
        !warnings.isEmpty
    }
}

// MARK: - Error and Warning Types

enum ValidationError: LocalizedError, Equatable {
    case emptyTitle
    case titleTooLong
    case invalidCharacters
    case duplicateVariableName(String)
    case emptyVariableName
    case invalidVariableName(String)
    case emptyChoices(String)
    case invalidQuickSlot(Int)
    case emptyCategory
    case categoryTooLong
    
    var errorDescription: String? {
        switch self {
        case .emptyTitle:
            return "Prompt title cannot be empty"
        case .titleTooLong:
            return "Prompt title is too long (max 100 characters)"
        case .invalidCharacters:
            return "Prompt title contains invalid characters"
        case .duplicateVariableName(let name):
            return "Duplicate variable name: \(name)"
        case .emptyVariableName:
            return "Variable name cannot be empty"
        case .invalidVariableName(let name):
            return "Invalid variable name: \(name)"
        case .emptyChoices(let name):
            return "Choice variable '\(name)' must have at least one option"
        case .invalidQuickSlot(let slot):
            return "Invalid quick slot: \(slot) (must be 1-9)"
        case .emptyCategory:
            return "Category name cannot be empty"
        case .categoryTooLong:
            return "Category name is too long (max 50 characters)"
        }
    }
}

enum ValidationWarning: Equatable {
    case emptyContent
    case contentTooLong
    case tooManyTags
    case emptyTag
    case tagTooLong
    case duplicateIds([UUID])
    case duplicateTitles([String])
    
    var warningDescription: String {
        switch self {
        case .emptyContent:
            return "Prompt content is empty"
        case .contentTooLong:
            return "Prompt content is very long (>10,000 characters)"
        case .tooManyTags:
            return "Too many tags (max 20 recommended)"
        case .emptyTag:
            return "Empty tag found"
        case .tagTooLong:
            return "Tag is too long (max 50 characters)"
        case .duplicateIds(let ids):
            return "Duplicate prompt IDs found: \(ids.count)"
        case .duplicateTitles(let titles):
            return "Duplicate titles found: \(titles.joined(separator: ", "))"
        }
    }
}