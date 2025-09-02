//
//  PromptStore.swift
//  Promptlet
//
//  Created by Josh Cohenzadeh on 8/29/25.
//

import Foundation
import SwiftUI
import Combine

enum PaletteSortMode: String, CaseIterable {
    case smart = "smart"     // Sort by frecency (frequency + recency)
    case manual = "manual"   // Sort by user-defined displayOrder
    
    var displayName: String {
        switch self {
        case .smart: return "Smart"
        case .manual: return "Manual"
        }
    }
    
    var icon: String {
        switch self {
        case .smart: return "sparkles"
        case .manual: return "list.number"
        }
    }
}

enum PromptStoreError: LocalizedError {
    case invalidData(String)
    case decodingFailed(Error)
    case encodingFailed(Error)
    case noPromptsToExport
    
    var errorDescription: String? {
        switch self {
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .encodingFailed(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .noPromptsToExport:
            return "No prompts available to export"
        }
    }
}

@MainActor
class PromptStore: ObservableObject {
    @Published var prompts: [Prompt] = []
    @Published var categories: [String] = ["Work", "Personal", "Templates"]
    @Published var searchText: String = ""
    @Published var selectedPlacement: PlacementMode = .cursor
    @Published var currentAppIdentifier: String = ""
    @Published var paletteSortMode: PaletteSortMode = .smart
    
    private let saveKey = "com.promptlet.prompts"
    private let preferencesKey = "com.promptlet.preferences"
    private var cancellables = Set<AnyCancellable>()
    
    var filteredPrompts: [Prompt] {
        var filtered = prompts.filter { !$0.isArchived }  // Hide archived prompts from palette
        
        if searchText.isEmpty {
            // When not searching, use the selected sort mode
            switch paletteSortMode {
            case .smart:
                return filtered.sorted { $0.frecencyScore > $1.frecencyScore }
            case .manual:
                return filtered.sorted { $0.displayOrder < $1.displayOrder }
            }
        }
        
        let searchLower = searchText.lowercased()
        
        if searchText.hasPrefix("#") {
            let tag = String(searchText.dropFirst()).lowercased()
            filtered = filtered.filter { prompt in
                prompt.tags.contains { $0.lowercased().contains(tag) }
            }
        } else if searchText.hasPrefix("mode:") {
            let mode = String(searchText.dropFirst(5)).lowercased()
            filtered = filtered.filter { prompt in
                prompt.defaultEnhancement.placement.rawValue.lowercased().contains(mode)
            }
        } else if searchText.hasPrefix("category:") {
            let category = String(searchText.dropFirst(9)).lowercased()
            filtered = filtered.filter { prompt in
                if category == "uncategorized" || category == "none" {
                    return prompt.category == nil
                }
                return prompt.category?.lowercased().contains(category) ?? false
            }
        } else {
            filtered = filtered.filter { prompt in
                prompt.title.lowercased().contains(searchLower) ||
                prompt.content.lowercased().contains(searchLower) ||
                prompt.tags.contains { $0.lowercased().contains(searchLower) }
            }
        }
        
        return filtered.sorted { $0.frecencyScore > $1.frecencyScore }
    }
    
    var sortedPrompts: [Prompt] {
        prompts.filter { !$0.isArchived }.sorted { $0.frecencyScore > $1.frecencyScore }
    }
    
    var favoritePrompts: [Prompt] {
        prompts.filter { $0.isFavorite }.sorted { $0.title < $1.title }
    }
    
    var recentPrompts: [Prompt] {
        prompts.sorted { $0.lastUsedDate > $1.lastUsedDate }.prefix(5).map { $0 }
    }
    
    var quickSlotPrompts: [Int: Prompt] {
        var slots: [Int: Prompt] = [:]
        for prompt in prompts {
            if let slot = prompt.quickSlot, slot >= 1 && slot <= 9 {
                slots[slot] = prompt
            }
        }
        return slots
    }
    
    init() {
        logDebug(.prompt, "Initializing store...")
        loadPrompts()
        loadPreferences()
        loadCategories()
        
        if prompts.isEmpty {
            logInfo(.prompt, "No prompts found, loading defaults...")
            prompts = Prompt.samplePrompts
            savePrompts()
        }
        
        $prompts
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePrompts()
            }
            .store(in: &cancellables)
        
        logSuccess(.prompt, "Store initialized with \(prompts.count) prompts")
    }
    
    func addPrompt(_ prompt: Prompt) {
        guard !prompt.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logError(.prompt, "Cannot add prompt with empty title")
            return
        }
        
        guard !prompts.contains(where: { $0.id == prompt.id }) else {
            logWarning(.prompt, "Prompt with ID \(prompt.id) already exists")
            return
        }
        
        var newPrompt = prompt
        // Assign next available displayOrder
        newPrompt.displayOrder = (prompts.map { $0.displayOrder }.max() ?? -1) + 1
        
        logInfo(.prompt, "Adding prompt: \(newPrompt.title)")
        prompts.append(newPrompt)
    }
    
    func updatePrompt(_ prompt: Prompt) {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else {
            logError(.prompt, "Cannot update prompt: not found with ID \(prompt.id)")
            return
        }
        
        guard !prompt.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            logError(.prompt, "Cannot update prompt with empty title")
            return
        }
        
        logInfo(.prompt, "Updating prompt: \(prompt.title)")
        prompts[index] = prompt
    }
    
    func deletePrompt(_ prompt: Prompt) {
        let initialCount = prompts.count
        prompts.removeAll { $0.id == prompt.id }
        
        if prompts.count < initialCount {
            logInfo(.prompt, "Deleted prompt: \(prompt.title)")
        } else {
            logWarning(.prompt, "No prompt found to delete with ID: \(prompt.id)")
        }
    }
    
    func duplicatePrompt(_ prompt: Prompt) {
        let newPrompt = Prompt(
            id: UUID(),
            title: "\(prompt.title) Copy",
            content: prompt.content,
            tags: prompt.tags,
            category: prompt.category,
            defaultEnhancement: prompt.defaultEnhancement,
            variables: prompt.variables,
            isFavorite: false,
            isArchived: false,
            quickSlot: nil,
            createdDate: Date(),
            lastUsedDate: Date(),
            usageCount: 0,
            perAppEnhancements: prompt.perAppEnhancements,
            displayOrder: 0  // Will be assigned in addPrompt
        )
        logInfo(.prompt, "Duplicating prompt: \(prompt.title) -> \(newPrompt.title)")
        addPrompt(newPrompt)
    }
    
    func recordUsage(for promptId: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == promptId }) else {
            logWarning(.prompt, "Cannot record usage: prompt not found with ID \(promptId)")
            return
        }
        
        prompts[index].recordUsage()
    }
    
    func getEnhancement(for prompt: Prompt) -> Enhancement {
        if !currentAppIdentifier.isEmpty,
           let appEnhancement = prompt.perAppEnhancements[currentAppIdentifier] {
            return appEnhancement
        }
        return prompt.defaultEnhancement
    }
    
    func setAppEnhancement(for promptId: UUID, appId: String, enhancement: Enhancement) {
        if let index = prompts.firstIndex(where: { $0.id == promptId }) {
            prompts[index].perAppEnhancements[appId] = enhancement
            logInfo(.prompt, "Set app-specific enhancement for \(prompts[index].title) in \(appId)")
        }
    }
    
    func importPrompts(from data: Data) throws {
        guard !data.isEmpty else {
            throw PromptStoreError.invalidData("Import data is empty")
        }
        
        let decoder = JSONDecoder()
        let imported: [Prompt]
        
        do {
            imported = try decoder.decode([Prompt].self, from: data)
        } catch {
            logError(.prompt, "Failed to decode import data: \(error)")
            throw PromptStoreError.decodingFailed(error)
        }
        
        logInfo(.prompt, "Importing \(imported.count) prompts...")
        var importedCount = 0
        
        for prompt in imported {
            if !prompts.contains(where: { $0.id == prompt.id }) {
                addPrompt(prompt)
                importedCount += 1
            }
        }
        
        logSuccess(.prompt, "Successfully imported \(importedCount) new prompts")
    }
    
    func exportPrompts() throws -> Data {
        guard !prompts.isEmpty else {
            throw PromptStoreError.noPromptsToExport
        }
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        
        do {
            let data = try encoder.encode(prompts)
            logInfo(.prompt, "Exported \(prompts.count) prompts")
            return data
        } catch {
            logError(.prompt, "Failed to export prompts: \(error)")
            throw PromptStoreError.encodingFailed(error)
        }
    }
    
    private func loadPrompts() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            logDebug(.prompt, "No saved prompts found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            prompts = try decoder.decode([Prompt].self, from: data)
            
            // Ensure all prompts have a displayOrder (for backward compatibility)
            var needsNormalization = false
            for (index, prompt) in prompts.enumerated() {
                if prompt.displayOrder == 0 && prompts.filter({ $0.displayOrder == 0 }).count == prompts.count {
                    // All have displayOrder 0, need to assign sequential values
                    prompts[index].displayOrder = index
                    needsNormalization = true
                }
            }
            
            if needsNormalization {
                savePrompts()
            }
            
            logInfo(.prompt, "Loaded \(prompts.count) prompts from storage")
        } catch {
            logError(.prompt, "Failed to load prompts: \(error)")
        }
    }
    
    private func savePrompts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(prompts)
            UserDefaults.standard.set(data, forKey: saveKey)
            logDebug(.prompt, "Saved \(prompts.count) prompts to storage")
        } catch {
            logError(.prompt, "Failed to save prompts: \(error)")
        }
    }
    
    private func loadPreferences() {
        if let placement = UserDefaults.standard.string(forKey: "\(preferencesKey).defaultPlacement"),
           let mode = PlacementMode(rawValue: placement) {
            selectedPlacement = mode
        }
        
        currentAppIdentifier = UserDefaults.standard.string(forKey: "\(preferencesKey).lastApp") ?? ""
        
        if let sortMode = UserDefaults.standard.string(forKey: "\(preferencesKey).paletteSortMode"),
           let mode = PaletteSortMode(rawValue: sortMode) {
            paletteSortMode = mode
        }
        
        logDebug(.prompt, "Loaded preferences - placement: \(selectedPlacement.rawValue), app: \(currentAppIdentifier), sort: \(paletteSortMode.rawValue)")
    }
    
    func savePreferences() {
        UserDefaults.standard.set(selectedPlacement.rawValue, forKey: "\(preferencesKey).defaultPlacement")
        UserDefaults.standard.set(currentAppIdentifier, forKey: "\(preferencesKey).lastApp")
        UserDefaults.standard.set(paletteSortMode.rawValue, forKey: "\(preferencesKey).paletteSortMode")
        logDebug(.prompt, "Saved preferences")
    }
    
    // MARK: - Category Management
    
    func addCategory(_ category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !categories.contains(trimmed) else { return }
        categories.append(trimmed)
        saveCategories()
    }
    
    func removeCategory(_ category: String) {
        categories.removeAll { $0 == category }
        // Reset prompts in this category to uncategorized
        for (index, prompt) in prompts.enumerated() where prompt.category == category {
            prompts[index].category = nil
        }
        saveCategories()
    }
    
    func renameCategory(from oldName: String, to newName: String) {
        guard let index = categories.firstIndex(of: oldName) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !categories.contains(trimmed) else { return }
        
        categories[index] = trimmed
        // Update prompts with this category
        for (index, prompt) in prompts.enumerated() where prompt.category == oldName {
            prompts[index].category = trimmed
        }
        saveCategories()
    }
    
    func promptsInCategory(_ category: String?) -> [Prompt] {
        let filtered: [Prompt]
        if category == nil {
            filtered = prompts.filter { $0.category == nil && !$0.isArchived }
        } else {
            filtered = prompts.filter { $0.category == category && !$0.isArchived }
        }
        return filtered.sorted { $0.displayOrder < $1.displayOrder }
    }
    
    func movePrompts(_ promptIds: Set<UUID>, toCategory category: String?) {
        for id in promptIds {
            if let index = prompts.firstIndex(where: { $0.id == id }) {
                prompts[index].category = category
            }
        }
    }
    
    func archivePrompts(_ promptIds: Set<UUID>) {
        for id in promptIds {
            if let index = prompts.firstIndex(where: { $0.id == id }) {
                prompts[index].isArchived = true
            }
        }
    }
    
    func unarchivePrompts(_ promptIds: Set<UUID>) {
        for id in promptIds {
            if let index = prompts.firstIndex(where: { $0.id == id }) {
                prompts[index].isArchived = false
            }
        }
    }
    
    private func saveCategories() {
        UserDefaults.standard.set(categories, forKey: "\(saveKey).categories")
    }
    
    private func loadCategories() {
        if let saved = UserDefaults.standard.array(forKey: "\(saveKey).categories") as? [String] {
            categories = saved
        }
    }
    
    // MARK: - Debug/Reset Functions
    
    func resetToDefaultPrompts() {
        logWarning(.prompt, "Resetting prompts to defaults")
        prompts = Prompt.samplePrompts
        categories = ["Work", "Personal", "Templates"]
        savePrompts()
        saveCategories()
        logSuccess(.prompt, "Reset to \(prompts.count) default prompts")
    }
    
    func clearAllPrompts() {
        logWarning(.prompt, "Clearing all prompts")
        prompts = []
        savePrompts()
        logSuccess(.prompt, "All prompts cleared")
    }
    
    // MARK: - Reordering Functions
    
    func reorderPrompts(from sourceIndices: IndexSet, to destination: Int, inCategory category: String? = nil) {
        var targetPrompts: [Prompt]
        
        if let category = category {
            // Filter to prompts in the specified category
            if category == "Uncategorized" {
                targetPrompts = prompts.filter { $0.category == nil }
            } else {
                targetPrompts = prompts.filter { $0.category == category }
            }
        } else {
            targetPrompts = prompts
        }
        
        // Sort by current displayOrder
        targetPrompts.sort { $0.displayOrder < $1.displayOrder }
        
        // Perform the move in the filtered array
        targetPrompts.move(fromOffsets: sourceIndices, toOffset: destination)
        
        // Update displayOrder for all affected prompts
        for (index, prompt) in targetPrompts.enumerated() {
            if let globalIndex = prompts.firstIndex(where: { $0.id == prompt.id }) {
                prompts[globalIndex].displayOrder = index
            }
        }
        
        // Re-normalize displayOrder for all prompts to avoid gaps
        normalizeDisplayOrder()
        
        logInfo(.prompt, "Reordered prompts")
    }
    
    private func normalizeDisplayOrder() {
        // Sort all prompts by current displayOrder and reassign sequential values
        let sorted = prompts.sorted { $0.displayOrder < $1.displayOrder }
        for (index, prompt) in sorted.enumerated() {
            if let globalIndex = prompts.firstIndex(where: { $0.id == prompt.id }) {
                prompts[globalIndex].displayOrder = index
            }
        }
    }
}