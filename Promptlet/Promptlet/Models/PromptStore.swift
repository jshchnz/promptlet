//
//  PromptStore.swift
//  Promptlet
//
//  Refactored to use service-based architecture for better maintainability
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
    @Published var searchText: String = ""
    @Published var selectedPlacement: PlacementMode = .cursor
    @Published var currentAppIdentifier: String = ""
    @Published var paletteSortMode: PaletteSortMode = .smart
    
    // Services
    private let searchService = PromptSearchService()
    private let persistenceService = PromptPersistenceService()
    private let validationService = PromptValidationService()
    private lazy var categoryManager = CategoryManager(
        persistenceService: persistenceService,
        validationService: validationService
    )
    
    private var cancellables = Set<AnyCancellable>()
    
    // Categories - delegated to CategoryManager
    var categories: [String] {
        categoryManager.getAllCategories()
    }
    
    // MARK: - Computed Properties (delegated to services)
    
    var filteredPrompts: [Prompt] {
        searchService.filterPrompts(prompts, searchText: searchText, sortMode: paletteSortMode)
    }
    
    var sortedPrompts: [Prompt] {
        searchService.getSortedPrompts(prompts)
    }
    
    var favoritePrompts: [Prompt] {
        searchService.getFavoritePrompts(prompts)
    }
    
    var recentPrompts: [Prompt] {
        searchService.getRecentPrompts(prompts)
    }
    
    var quickSlotPrompts: [Int: Prompt] {
        searchService.getQuickSlotPrompts(prompts)
    }
    
    init() {
        logDebug(.prompt, "Initializing store...")
        loadPrompts()
        loadPreferences()
        
        if prompts.isEmpty {
            logInfo(.prompt, "No prompts found, loading defaults...")
            prompts = Prompt.samplePrompts
            savePrompts()
        }
        
        // Auto-save prompts when they change
        $prompts
            .debounce(for: .seconds(Timing.debounceDelay), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePrompts()
            }
            .store(in: &cancellables)
        
        logSuccess(.prompt, "Store initialized with \(prompts.count) prompts")
    }
    
    // MARK: - Prompt Management (with validation)
    
    func addPrompt(_ prompt: Prompt) {
        guard validationService.canAddPrompt(prompt, to: prompts) else {
            let validation = validationService.validatePrompt(prompt)
            if case .invalid(let errors, _) = validation {
                logError(.prompt, "Cannot add prompt: \(errors.first?.errorDescription ?? "Validation failed")")
            }
            return
        }
        
        var newPrompt = validationService.sanitizePrompt(prompt)
        // Assign next available displayOrder
        newPrompt.displayOrder = (prompts.map { $0.displayOrder }.max() ?? -1) + 1
        
        logInfo(.prompt, "Adding prompt: \(newPrompt.title)")
        trackPromptAction(.promptCreated, promptId: newPrompt.id)
        prompts.append(newPrompt)
    }
    
    func updatePrompt(_ prompt: Prompt) {
        guard let index = prompts.firstIndex(where: { $0.id == prompt.id }) else {
            logError(.prompt, ErrorMessages.promptNotFound)
            return
        }
        
        guard validationService.canUpdatePrompt(prompt) else {
            logError(.prompt, "Cannot update prompt: validation failed")
            return
        }
        
        let sanitizedPrompt = validationService.sanitizePrompt(prompt)
        logInfo(.prompt, "Updating prompt: \(sanitizedPrompt.title)")
        trackPromptAction(.promptEdited, promptId: sanitizedPrompt.id)
        prompts[index] = sanitizedPrompt
    }
    
    func deletePrompt(_ prompt: Prompt) {
        let initialCount = prompts.count
        prompts.removeAll { $0.id == prompt.id }
        
        if prompts.count < initialCount {
            logInfo(.prompt, "Deleted prompt: \(prompt.title)")
            trackPromptAction(.promptDeleted, promptId: prompt.id)
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
        trackPromptAction(.promptDuplicated, promptId: prompt.id)
        addPrompt(newPrompt)
    }
    
    func recordUsage(for promptId: UUID) {
        guard let index = prompts.firstIndex(where: { $0.id == promptId }) else {
            logWarning(.prompt, "Cannot record usage: prompt not found with ID \(promptId)")
            return
        }
        
        prompts[index].recordUsage()
    }
    
    func clearQuickSlots() {
        logInfo(.prompt, "Clearing all quick slot assignments")
        for index in prompts.indices {
            if prompts[index].quickSlot != nil {
                logDebug(.prompt, "Removing quick slot \(prompts[index].quickSlot!) from \(prompts[index].title)")
                let updatedPrompt = Prompt(
                    id: prompts[index].id,
                    title: prompts[index].title,
                    content: prompts[index].content,
                    tags: prompts[index].tags,
                    category: prompts[index].category,
                    defaultEnhancement: prompts[index].defaultEnhancement,
                    variables: prompts[index].variables,
                    isFavorite: prompts[index].isFavorite,
                    isArchived: prompts[index].isArchived,
                    quickSlot: nil, // Clear the quick slot
                    createdDate: prompts[index].createdDate,
                    lastUsedDate: prompts[index].lastUsedDate,
                    usageCount: prompts[index].usageCount,
                    perAppEnhancements: prompts[index].perAppEnhancements,
                    displayOrder: prompts[index].displayOrder
                )
                prompts[index] = updatedPrompt
            }
        }
        logInfo(.prompt, "Completed clearing all quick slot assignments")
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
    
    // MARK: - Import/Export (delegated to persistence service)
    
    func importPrompts(from data: Data) throws {
        do {
            let newPrompts = try persistenceService.importPrompts(from: data, currentPrompts: prompts)
            
            var importedCount = 0
            for prompt in newPrompts {
                addPrompt(prompt)
                importedCount += 1
            }
            
            logSuccess(.prompt, "Successfully imported \(importedCount) new prompts")
            trackAnalytics(.promptImported, properties: ["count": importedCount])
        } catch {
            logError(.prompt, "Import failed: \(error.localizedDescription)")
            trackError(.importFailed, error: error.localizedDescription, context: "prompt_import")
            throw error
        }
    }
    
    func exportPrompts() throws -> Data {
        do {
            let data = try persistenceService.exportPrompts(prompts)
            trackAnalytics(.promptExported, properties: ["count": prompts.count])
            return data
        } catch {
            logError(.prompt, "Export failed: \(error.localizedDescription)")
            trackError(.exportFailed, error: error.localizedDescription, context: "prompt_export")
            throw error
        }
    }
    
    // MARK: - Persistence (delegated to persistence service)
    
    private func loadPrompts() {
        prompts = persistenceService.loadPrompts()
    }
    
    private func savePrompts() {
        persistenceService.savePrompts(prompts)
    }
    
    private func loadPreferences() {
        let (placement, appId, sortMode) = persistenceService.loadPreferences()
        selectedPlacement = placement
        currentAppIdentifier = appId
        paletteSortMode = sortMode
    }
    
    func savePreferences() {
        persistenceService.savePreferences(
            selectedPlacement: selectedPlacement,
            currentAppIdentifier: currentAppIdentifier,
            paletteSortMode: paletteSortMode
        )
    }
    
    // MARK: - Category Management (delegated to category manager)
    
    func addCategory(_ category: String) {
        _ = categoryManager.addCategory(category)
    }
    
    func removeCategory(_ category: String) {
        if categoryManager.removeCategory(category) {
            // Reset prompts in this category to uncategorized
            let movedCount = categoryManager.movePromptsToCategory(
                Set(prompts.filter { $0.category == category }.map { $0.id }),
                to: nil,
                in: &prompts
            )
            logInfo(.prompt, "Moved \(movedCount) prompts from removed category '\(category)' to uncategorized")
        }
    }
    
    func renameCategory(from oldName: String, to newName: String) {
        if categoryManager.renameCategory(from: oldName, to: newName) {
            // Update prompts with this category
            for (index, prompt) in prompts.enumerated() where prompt.category == oldName {
                prompts[index].category = newName
            }
        }
    }
    
    func promptsInCategory(_ category: String?) -> [Prompt] {
        return searchService.getPromptsInCategory(prompts, category: category)
    }
    
    func movePrompts(_ promptIds: Set<UUID>, toCategory category: String?) {
        _ = categoryManager.movePromptsToCategory(promptIds, to: category, in: &prompts)
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
    
    // MARK: - Debug/Reset Functions
    
    func resetToDefaultPrompts() {
        logWarning(.prompt, "Resetting prompts to defaults")
        trackAnalytics(.promptsResetToDefault)
        prompts = Prompt.samplePrompts
        categoryManager.resetToDefaults()
        savePrompts()
        logSuccess(.prompt, "Reset to \(prompts.count) default prompts")
    }
    
    func clearAllPrompts() {
        logWarning(.prompt, "Clearing all prompts")
        trackAnalytics(.promptsClearedAll, properties: ["previous_count": prompts.count])
        prompts = []
        savePrompts()
        logSuccess(.prompt, "All prompts cleared")
    }
    
    // MARK: - Reordering Functions
    
    func reorderPrompts(from sourceIndices: IndexSet, to destination: Int, inCategory category: String? = nil) {
        var targetPrompts: [Prompt]
        
        if let category = category {
            targetPrompts = promptsInCategory(category == "Uncategorized" ? nil : category)
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
    
    // MARK: - Service Access (for advanced features)
    
    func getSearchService() -> PromptSearchService {
        return searchService
    }
    
    func getValidationService() -> PromptValidationService {
        return validationService
    }
    
    func getCategoryManager() -> CategoryManager {
        return categoryManager
    }
    
    func getPersistenceService() -> PromptPersistenceService {
        return persistenceService
    }
}