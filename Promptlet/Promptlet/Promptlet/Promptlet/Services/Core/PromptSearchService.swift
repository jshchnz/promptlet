//
//  PromptSearchService.swift
//  Promptlet
//
//  Handles search and filtering logic for prompts
//

import Foundation

@MainActor
class PromptSearchService: ObservableObject {
    
    // MARK: - Search & Filtering
    
    func filterPrompts(_ prompts: [Prompt], 
                      searchText: String, 
                      sortMode: PaletteSortMode) -> [Prompt] {
        var filtered = prompts.filter { !$0.isArchived }
        
        if searchText.isEmpty {
            return applySortMode(filtered, sortMode: sortMode)
        }
        
        filtered = applySearchFilter(filtered, searchText: searchText)
        return applySortMode(filtered, sortMode: .smart) // Always use smart sort for search results
    }
    
    private func applySearchFilter(_ prompts: [Prompt], searchText: String) -> [Prompt] {
        let searchLower = searchText.lowercased()
        
        if searchText.hasPrefix(Search.tagPrefix) {
            return filterByTag(prompts, tag: String(searchText.dropFirst()).lowercased())
        } else if searchText.hasPrefix(Search.modePrefix) {
            return filterByMode(prompts, mode: String(searchText.dropFirst(5)).lowercased())
        } else if searchText.hasPrefix(Search.categoryPrefix) {
            return filterByCategory(prompts, category: String(searchText.dropFirst(9)).lowercased())
        } else {
            return filterByContent(prompts, searchText: searchLower)
        }
    }
    
    private func filterByTag(_ prompts: [Prompt], tag: String) -> [Prompt] {
        return prompts.filter { prompt in
            prompt.tags.contains { $0.lowercased().contains(tag) }
        }
    }
    
    private func filterByMode(_ prompts: [Prompt], mode: String) -> [Prompt] {
        return prompts.filter { prompt in
            prompt.defaultEnhancement.placement.rawValue.lowercased().contains(mode)
        }
    }
    
    private func filterByCategory(_ prompts: [Prompt], category: String) -> [Prompt] {
        return prompts.filter { prompt in
            if Search.uncategorizedKeywords.contains(category) {
                return prompt.category == nil
            }
            return prompt.category?.lowercased().contains(category) ?? false
        }
    }
    
    private func filterByContent(_ prompts: [Prompt], searchText: String) -> [Prompt] {
        return prompts.filter { prompt in
            prompt.title.lowercased().contains(searchText) ||
            prompt.content.lowercased().contains(searchText) ||
            prompt.tags.contains { $0.lowercased().contains(searchText) }
        }
    }
    
    private func applySortMode(_ prompts: [Prompt], sortMode: PaletteSortMode) -> [Prompt] {
        switch sortMode {
        case .smart:
            return prompts.sorted { $0.frecencyScore > $1.frecencyScore }
        case .manual:
            return prompts.sorted { $0.displayOrder < $1.displayOrder }
        }
    }
    
    // MARK: - Specialized Queries
    
    func getFavoritePrompts(_ prompts: [Prompt]) -> [Prompt] {
        return prompts
            .filter { $0.isFavorite }
            .sorted { $0.title < $1.title }
    }
    
    func getRecentPrompts(_ prompts: [Prompt]) -> [Prompt] {
        return Array(prompts
            .sorted { $0.lastUsedDate > $1.lastUsedDate }
            .prefix(Search.maxRecentPrompts))
    }
    
    func getSortedPrompts(_ prompts: [Prompt]) -> [Prompt] {
        return prompts
            .filter { !$0.isArchived }
            .sorted { $0.frecencyScore > $1.frecencyScore }
    }
    
    func getQuickSlotPrompts(_ prompts: [Prompt]) -> [Int: Prompt] {
        var slots: [Int: Prompt] = [:]
        for prompt in prompts {
            if let slot = prompt.quickSlot, 
               slot >= AppConfig.QuickSlots.minSlot && 
               slot <= AppConfig.QuickSlots.maxSlots {
                slots[slot] = prompt
            }
        }
        return slots
    }
    
    func getPromptsInCategory(_ prompts: [Prompt], category: String?) -> [Prompt] {
        let filtered: [Prompt]
        if category == nil {
            filtered = prompts.filter { $0.category == nil && !$0.isArchived }
        } else {
            filtered = prompts.filter { $0.category == category && !$0.isArchived }
        }
        return filtered.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    // MARK: - Search Analytics
    
    func getSearchSuggestions(for searchText: String, from prompts: [Prompt]) -> [String] {
        let lowercased = searchText.lowercased()
        var suggestions: Set<String> = []
        
        // Tag suggestions
        if searchText.hasPrefix(Search.tagPrefix) {
            let tagSearch = String(searchText.dropFirst()).lowercased()
            for prompt in prompts {
                for tag in prompt.tags {
                    if tag.lowercased().contains(tagSearch) && tag.lowercased() != tagSearch {
                        suggestions.insert("\(Search.tagPrefix)\(tag)")
                    }
                }
            }
        }
        // Category suggestions
        else if searchText.hasPrefix(Search.categoryPrefix) {
            let categorySearch = String(searchText.dropFirst(9)).lowercased()
            let categories = Set(prompts.compactMap { $0.category })
            for category in categories {
                if category.lowercased().contains(categorySearch) && category.lowercased() != categorySearch {
                    suggestions.insert("\(Search.categoryPrefix)\(category)")
                }
            }
        }
        // General content suggestions
        else {
            for prompt in prompts {
                if prompt.title.lowercased().contains(lowercased) && 
                   prompt.title.lowercased() != lowercased {
                    suggestions.insert(prompt.title)
                }
            }
        }
        
        return Array(suggestions).sorted().prefix(5).map { String($0) }
    }
    
    // MARK: - Performance Optimized Search
    
    func performanceOptimizedFilter(_ prompts: [Prompt], 
                                   searchText: String,
                                   sortMode: PaletteSortMode,
                                   limit: Int = 50) -> [Prompt] {
        if searchText.isEmpty {
            let filtered = prompts.filter { !$0.isArchived }
            let sorted = applySortMode(filtered, sortMode: sortMode)
            return Array(sorted.prefix(limit))
        }
        
        let filtered = applySearchFilter(prompts, searchText: searchText)
        let sorted = applySortMode(filtered, sortMode: .smart)
        return Array(sorted.prefix(limit))
    }
}