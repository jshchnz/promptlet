//
//  PromptPersistenceService.swift
//  Promptlet
//
//  Handles persistence and data storage for prompts
//

import Foundation

@MainActor
class PromptPersistenceService: ObservableObject {
    
    // MARK: - Prompt Persistence
    
    func savePrompts(_ prompts: [Prompt]) {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(prompts)
            UserDefaults.standard.set(data, forKey: UserDefaultsKeys.prompts)
            logDebug(.prompt, "Saved \(prompts.count) prompts to storage")
        } catch {
            logError(.prompt, "Failed to save prompts: \(error)")
        }
    }
    
    func loadPrompts() -> [Prompt] {
        guard let data = UserDefaults.standard.data(forKey: UserDefaultsKeys.prompts) else {
            logDebug(.prompt, "No saved prompts found")
            return []
        }
        
        do {
            let decoder = JSONDecoder()
            var prompts = try decoder.decode([Prompt].self, from: data)
            
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
                savePrompts(prompts)
                logDebug(.prompt, "Normalized prompt display orders")
            }
            
            logInfo(.prompt, "Loaded \(prompts.count) prompts from storage")
            return prompts
        } catch {
            logError(.prompt, "Failed to load prompts: \(error)")
            return []
        }
    }
    
    // MARK: - Preferences Persistence
    
    func savePreferences(selectedPlacement: PlacementMode, 
                        currentAppIdentifier: String, 
                        paletteSortMode: PaletteSortMode) {
        UserDefaults.standard.set(selectedPlacement.rawValue, 
                                 forKey: UserDefaultsKeys.Preferences.defaultPlacement)
        UserDefaults.standard.set(currentAppIdentifier, 
                                 forKey: UserDefaultsKeys.Preferences.lastApp)
        UserDefaults.standard.set(paletteSortMode.rawValue, 
                                 forKey: UserDefaultsKeys.Preferences.paletteSortMode)
        logDebug(.prompt, "Saved preferences")
    }
    
    func loadPreferences() -> (placement: PlacementMode, appId: String, sortMode: PaletteSortMode) {
        let placement: PlacementMode
        if let placementString = UserDefaults.standard.string(forKey: UserDefaultsKeys.Preferences.defaultPlacement),
           let mode = PlacementMode(rawValue: placementString) {
            placement = mode
        } else {
            placement = .cursor
        }
        
        let appId = UserDefaults.standard.string(forKey: UserDefaultsKeys.Preferences.lastApp) ?? ""
        
        let sortMode: PaletteSortMode
        if let sortModeString = UserDefaults.standard.string(forKey: UserDefaultsKeys.Preferences.paletteSortMode),
           let mode = PaletteSortMode(rawValue: sortModeString) {
            sortMode = mode
        } else {
            sortMode = .smart
        }
        
        logDebug(.prompt, "Loaded preferences - placement: \(placement.rawValue), app: \(appId), sort: \(sortMode.rawValue)")
        
        return (placement, appId, sortMode)
    }
    
    // MARK: - Category Persistence
    
    func saveCategories(_ categories: [String]) {
        UserDefaults.standard.set(categories, forKey: UserDefaultsKeys.categories)
        logDebug(.prompt, "Saved \(categories.count) categories")
    }
    
    func loadCategories() -> [String] {
        if let saved = UserDefaults.standard.array(forKey: UserDefaultsKeys.categories) as? [String] {
            logDebug(.prompt, "Loaded \(saved.count) categories")
            return saved
        } else {
            logDebug(.prompt, "No saved categories found, using defaults")
            return SampleData.categories
        }
    }
    
    // MARK: - Import/Export
    
    func exportPrompts(_ prompts: [Prompt]) throws -> Data {
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
    
    func importPrompts(from data: Data, currentPrompts: [Prompt]) throws -> [Prompt] {
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
        var newPrompts: [Prompt] = []
        
        for prompt in imported {
            if !currentPrompts.contains(where: { $0.id == prompt.id }) {
                newPrompts.append(prompt)
            }
        }
        
        logSuccess(.prompt, "Successfully identified \(newPrompts.count) new prompts for import")
        return newPrompts
    }
    
    // MARK: - Backup & Recovery
    
    func createBackup() throws -> Data {
        let allData: [String: Any] = [
            "prompts": UserDefaults.standard.data(forKey: UserDefaultsKeys.prompts) ?? Data(),
            "categories": UserDefaults.standard.array(forKey: UserDefaultsKeys.categories) ?? [],
            "preferences": [
                "placement": UserDefaults.standard.string(forKey: UserDefaultsKeys.Preferences.defaultPlacement) ?? "",
                "appId": UserDefaults.standard.string(forKey: UserDefaultsKeys.Preferences.lastApp) ?? "",
                "sortMode": UserDefaults.standard.string(forKey: UserDefaultsKeys.Preferences.paletteSortMode) ?? ""
            ]
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: allData, options: .prettyPrinted)
            logInfo(.prompt, "Backup created successfully")
            return data
        } catch {
            logError(.prompt, "Failed to create backup: \(error)")
            throw PromptStoreError.encodingFailed(error)
        }
    }
    
    func restoreFromBackup(_ data: Data) throws {
        do {
            guard let backupData = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw PromptStoreError.invalidData("Invalid backup format")
            }
            
            // Restore prompts
            if let promptsData = backupData["prompts"] as? Data {
                UserDefaults.standard.set(promptsData, forKey: UserDefaultsKeys.prompts)
            }
            
            // Restore categories
            if let categories = backupData["categories"] as? [String] {
                UserDefaults.standard.set(categories, forKey: UserDefaultsKeys.categories)
            }
            
            // Restore preferences
            if let preferences = backupData["preferences"] as? [String: String] {
                if let placement = preferences["placement"], !placement.isEmpty {
                    UserDefaults.standard.set(placement, forKey: UserDefaultsKeys.Preferences.defaultPlacement)
                }
                if let appId = preferences["appId"] {
                    UserDefaults.standard.set(appId, forKey: UserDefaultsKeys.Preferences.lastApp)
                }
                if let sortMode = preferences["sortMode"], !sortMode.isEmpty {
                    UserDefaults.standard.set(sortMode, forKey: UserDefaultsKeys.Preferences.paletteSortMode)
                }
            }
            
            logSuccess(.prompt, "Backup restored successfully")
        } catch {
            logError(.prompt, "Failed to restore backup: \(error)")
            throw PromptStoreError.decodingFailed(error)
        }
    }
    
    // MARK: - Data Validation
    
    func validateStoredData() -> Bool {
        // Check if we can load prompts without errors
        let prompts = loadPrompts()
        
        // Check if categories are valid
        let categories = loadCategories()
        let validCategories = categories.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Check preferences
        let (_, _, _) = loadPreferences()
        
        logInfo(.prompt, "Data validation: \(prompts.count) prompts, \(categories.count) categories, valid: \(validCategories)")
        
        return validCategories
    }
    
    // MARK: - Storage Statistics
    
    func getStorageStatistics() -> StorageStatistics {
        let prompts = loadPrompts()
        let categories = loadCategories()
        
        let totalPrompts = prompts.count
        let archivedPrompts = prompts.filter { $0.isArchived }.count
        let favoritePrompts = prompts.filter { $0.isFavorite }.count
        let totalCategories = categories.count
        let avgUsageCount = prompts.isEmpty ? 0 : prompts.map { $0.usageCount }.reduce(0, +) / prompts.count
        
        return StorageStatistics(
            totalPrompts: totalPrompts,
            archivedPrompts: archivedPrompts,
            favoritePrompts: favoritePrompts,
            totalCategories: totalCategories,
            averageUsageCount: avgUsageCount
        )
    }
}

// MARK: - Supporting Types

struct StorageStatistics {
    let totalPrompts: Int
    let archivedPrompts: Int
    let favoritePrompts: Int
    let totalCategories: Int
    let averageUsageCount: Int
    
    var activePrompts: Int {
        totalPrompts - archivedPrompts
    }
    
    var description: String {
        return """
        Total Prompts: \(totalPrompts)
        Active Prompts: \(activePrompts)
        Archived Prompts: \(archivedPrompts)
        Favorite Prompts: \(favoritePrompts)
        Categories: \(totalCategories)
        Average Usage: \(averageUsageCount)
        """
    }
}