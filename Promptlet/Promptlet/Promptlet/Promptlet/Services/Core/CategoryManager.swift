//
//  CategoryManager.swift
//  Promptlet
//
//  Handles category management and organization logic
//

import Foundation
import Combine

@MainActor
class CategoryManager: ObservableObject {
    @Published private(set) var categories: [String] = []
    
    private let persistenceService: PromptPersistenceService
    private let validationService: PromptValidationService
    
    init(persistenceService: PromptPersistenceService, 
         validationService: PromptValidationService) {
        self.persistenceService = persistenceService
        self.validationService = validationService
        loadCategories()
    }
    
    // MARK: - Category Management
    
    func addCategory(_ category: String) -> Bool {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate category
        let validation = validationService.validateCategory(trimmed)
        guard case .valid = validation else {
            logError(.prompt, "Invalid category: \(trimmed)")
            return false
        }
        
        // Check for duplicates
        guard !categories.contains(trimmed) else {
            logWarning(.prompt, "Category already exists: \(trimmed)")
            return false
        }
        
        categories.append(trimmed)
        saveCategories()
        logInfo(.prompt, "Added category: \(trimmed)")
        return true
    }
    
    func removeCategory(_ category: String) -> Bool {
        guard let index = categories.firstIndex(of: category) else {
            logWarning(.prompt, "Category not found for removal: \(category)")
            return false
        }
        
        categories.remove(at: index)
        saveCategories()
        logInfo(.prompt, "Removed category: \(category)")
        return true
    }
    
    func renameCategory(from oldName: String, to newName: String) -> Bool {
        guard let index = categories.firstIndex(of: oldName) else {
            logError(.prompt, "Source category not found: \(oldName)")
            return false
        }
        
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Validate new category name
        let validation = validationService.validateCategory(trimmed)
        guard case .valid = validation else {
            logError(.prompt, "Invalid new category name: \(trimmed)")
            return false
        }
        
        // Check for duplicates (excluding the current category)
        guard !categories.contains(trimmed) || trimmed == oldName else {
            logError(.prompt, "Category with new name already exists: \(trimmed)")
            return false
        }
        
        categories[index] = trimmed
        saveCategories()
        logInfo(.prompt, "Renamed category from '\(oldName)' to '\(trimmed)'")
        return true
    }
    
    func reorderCategories(from sourceIndices: IndexSet, to destination: Int) {
        categories.move(fromOffsets: sourceIndices, toOffset: destination)
        saveCategories()
        logInfo(.prompt, "Reordered categories")
    }
    
    // MARK: - Category Queries
    
    func getAllCategories() -> [String] {
        return categories
    }
    
    func getCategoriesSortedByName() -> [String] {
        return categories.sorted()
    }
    
    func getCategoriesWithCounts(_ prompts: [Prompt]) -> [(category: String?, count: Int)] {
        var categoryCounts: [String?: Int] = [:]
        
        // Count prompts in each category
        for prompt in prompts.filter({ !$0.isArchived }) {
            let category = prompt.category
            categoryCounts[category, default: 0] += 1
        }
        
        // Convert to sorted array
        var result: [(category: String?, count: Int)] = []
        
        // Add uncategorized first
        if let uncategorizedCount = categoryCounts[nil], uncategorizedCount > 0 {
            result.append((category: nil, count: uncategorizedCount))
        }
        
        // Add categorized prompts sorted by category name
        for category in categories.sorted() {
            if let count = categoryCounts[category], count > 0 {
                result.append((category: category, count: count))
            }
        }
        
        return result
    }
    
    func getEmptyCategories(_ prompts: [Prompt]) -> [String] {
        let usedCategories = Set(prompts.compactMap { $0.category })
        return categories.filter { !usedCategories.contains($0) }
    }
    
    func categoryExists(_ category: String) -> Bool {
        return categories.contains(category)
    }
    
    // MARK: - Prompt Category Operations
    
    func movePromptsToCategory(_ promptIds: Set<UUID>, 
                              to category: String?, 
                              in prompts: inout [Prompt]) -> Int {
        var movedCount = 0
        
        // Validate category if provided
        if let category = category {
            guard categoryExists(category) else {
                logError(.prompt, "Target category does not exist: \(category)")
                return 0
            }
        }
        
        for id in promptIds {
            if let index = prompts.firstIndex(where: { $0.id == id }) {
                prompts[index].category = category
                movedCount += 1
            }
        }
        
        let categoryName = category ?? "uncategorized"
        logInfo(.prompt, "Moved \(movedCount) prompts to category: \(categoryName)")
        return movedCount
    }
    
    func archivePromptsInCategory(_ category: String?, 
                                 in prompts: inout [Prompt]) -> Int {
        var archivedCount = 0
        
        for (index, prompt) in prompts.enumerated() {
            if prompt.category == category {
                prompts[index].isArchived = true
                archivedCount += 1
            }
        }
        
        let categoryName = category ?? "uncategorized"
        logInfo(.prompt, "Archived \(archivedCount) prompts from category: \(categoryName)")
        return archivedCount
    }
    
    func deleteCategory(_ category: String, 
                       movePromptsTo newCategory: String?, 
                       in prompts: inout [Prompt]) -> (removed: Bool, promptsMoved: Int) {
        guard removeCategory(category) else {
            return (removed: false, promptsMoved: 0)
        }
        
        // Move prompts to new category or uncategorized
        var movedCount = 0
        for (index, prompt) in prompts.enumerated() {
            if prompt.category == category {
                prompts[index].category = newCategory
                movedCount += 1
            }
        }
        
        let targetName = newCategory ?? "uncategorized"
        logInfo(.prompt, "Deleted category '\(category)' and moved \(movedCount) prompts to '\(targetName)'")
        
        return (removed: true, promptsMoved: movedCount)
    }
    
    // MARK: - Category Statistics
    
    func getCategoryStatistics(_ prompts: [Prompt]) -> CategoryStatistics {
        let activePrompts = prompts.filter { !$0.isArchived }
        let categoryCounts = getCategoriesWithCounts(activePrompts)
        
        let totalCategories = categories.count
        let usedCategories = categoryCounts.filter { $0.category != nil }.count
        let uncategorizedCount = categoryCounts.first { $0.category == nil }?.count ?? 0
        let emptyCategories = getEmptyCategories(activePrompts).count
        
        let mostPopularCategory = categoryCounts
            .filter { $0.category != nil }
            .max { $0.count < $1.count }
        
        return CategoryStatistics(
            totalCategories: totalCategories,
            usedCategories: usedCategories,
            emptyCategories: emptyCategories,
            uncategorizedCount: uncategorizedCount,
            mostPopularCategory: mostPopularCategory?.category,
            mostPopularCategoryCount: mostPopularCategory?.count ?? 0
        )
    }
    
    // MARK: - Batch Operations
    
    func cleanupEmptyCategories(_ prompts: [Prompt]) -> [String] {
        let emptyCategories = getEmptyCategories(prompts)
        var removedCategories: [String] = []
        
        for category in emptyCategories {
            if removeCategory(category) {
                removedCategories.append(category)
            }
        }
        
        logInfo(.prompt, "Cleaned up \(removedCategories.count) empty categories")
        return removedCategories
    }
    
    func mergeCategories(_ sourceCategories: [String], 
                        into targetCategory: String, 
                        in prompts: inout [Prompt]) -> Int {
        guard categoryExists(targetCategory) else {
            logError(.prompt, "Target category does not exist: \(targetCategory)")
            return 0
        }
        
        var mergedCount = 0
        
        for sourceCategory in sourceCategories {
            guard sourceCategory != targetCategory else { continue }
            
            // Move all prompts from source to target category
            for (index, prompt) in prompts.enumerated() {
                if prompt.category == sourceCategory {
                    prompts[index].category = targetCategory
                    mergedCount += 1
                }
            }
            
            // Remove the source category
            _ = removeCategory(sourceCategory)
        }
        
        logInfo(.prompt, "Merged \(sourceCategories.count) categories into '\(targetCategory)', moved \(mergedCount) prompts")
        return mergedCount
    }
    
    // MARK: - Private Methods
    
    private func loadCategories() {
        categories = persistenceService.loadCategories()
    }
    
    private func saveCategories() {
        persistenceService.saveCategories(categories)
    }
    
    // MARK: - Reset Methods
    
    func resetToDefaults() {
        categories = SampleData.categories
        saveCategories()
        logInfo(.prompt, "Reset categories to defaults")
    }
}

// MARK: - Supporting Types

struct CategoryStatistics {
    let totalCategories: Int
    let usedCategories: Int
    let emptyCategories: Int
    let uncategorizedCount: Int
    let mostPopularCategory: String?
    let mostPopularCategoryCount: Int
    
    var utilizationRate: Double {
        guard totalCategories > 0 else { return 0 }
        return Double(usedCategories) / Double(totalCategories)
    }
    
    var description: String {
        return """
        Total Categories: \(totalCategories)
        Used Categories: \(usedCategories)
        Empty Categories: \(emptyCategories)
        Uncategorized Prompts: \(uncategorizedCount)
        Most Popular: \(mostPopularCategory ?? "None") (\(mostPopularCategoryCount))
        Utilization Rate: \(String(format: "%.1f", utilizationRate * 100))%
        """
    }
}