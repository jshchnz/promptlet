//
//  PromptStore.swift
//  Promptlet
//
//  Created by Josh Cohenzadeh on 8/29/25.
//

import Foundation
import SwiftUI
import Combine

@MainActor
class PromptStore: ObservableObject {
    @Published var prompts: [Prompt] = []
    @Published var searchText: String = ""
    @Published var selectedPlacement: PlacementMode = .cursor
    @Published var currentAppIdentifier: String = ""
    
    private let saveKey = "com.promptlet.prompts"
    private let preferencesKey = "com.promptlet.preferences"
    private var cancellables = Set<AnyCancellable>()
    
    var filteredPrompts: [Prompt] {
        if searchText.isEmpty {
            return sortedPrompts
        }
        
        let searchLower = searchText.lowercased()
        
        if searchText.hasPrefix("#") {
            let tag = String(searchText.dropFirst()).lowercased()
            return sortedPrompts.filter { prompt in
                prompt.tags.contains { $0.lowercased().contains(tag) }
            }
        }
        
        if searchText.hasPrefix("mode:") {
            let mode = String(searchText.dropFirst(5)).lowercased()
            return sortedPrompts.filter { prompt in
                prompt.defaultEnhancement.placement.rawValue.lowercased().contains(mode)
            }
        }
        
        return sortedPrompts.filter { prompt in
            prompt.title.lowercased().contains(searchLower) ||
            prompt.content.lowercased().contains(searchLower) ||
            prompt.tags.contains { $0.lowercased().contains(searchLower) }
        }
    }
    
    var sortedPrompts: [Prompt] {
        prompts.sorted { $0.frecencyScore > $1.frecencyScore }
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
        print("[PromptStore] Initializing...")
        loadPrompts()
        loadPreferences()
        
        if prompts.isEmpty {
            print("[PromptStore] No prompts found, loading defaults...")
            prompts = Prompt.samplePrompts
            savePrompts()
        }
        
        $prompts
            .debounce(for: .seconds(0.5), scheduler: RunLoop.main)
            .sink { [weak self] _ in
                self?.savePrompts()
            }
            .store(in: &cancellables)
        
        print("[PromptStore] Initialized with \(prompts.count) prompts")
    }
    
    func addPrompt(_ prompt: Prompt) {
        print("[PromptStore] Adding prompt: \(prompt.title)")
        prompts.append(prompt)
    }
    
    func updatePrompt(_ prompt: Prompt) {
        if let index = prompts.firstIndex(where: { $0.id == prompt.id }) {
            print("[PromptStore] Updating prompt: \(prompt.title)")
            prompts[index] = prompt
        }
    }
    
    func deletePrompt(_ prompt: Prompt) {
        print("[PromptStore] Deleting prompt: \(prompt.title)")
        prompts.removeAll { $0.id == prompt.id }
    }
    
    func duplicatePrompt(_ prompt: Prompt) {
        let newPrompt = Prompt(
            id: UUID(),
            title: "\(prompt.title) Copy",
            content: prompt.content,
            tags: prompt.tags,
            defaultEnhancement: prompt.defaultEnhancement,
            variables: prompt.variables,
            isFavorite: false,
            quickSlot: nil,
            createdDate: Date(),
            lastUsedDate: Date(),
            usageCount: 0,
            perAppEnhancements: prompt.perAppEnhancements
        )
        print("[PromptStore] Duplicating prompt: \(prompt.title) -> \(newPrompt.title)")
        addPrompt(newPrompt)
    }
    
    func recordUsage(for promptId: UUID) {
        if let index = prompts.firstIndex(where: { $0.id == promptId }) {
            prompts[index].recordUsage()
        }
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
            print("[PromptStore] Set app-specific enhancement for \(prompts[index].title) in \(appId)")
        }
    }
    
    func importPrompts(from data: Data) throws {
        let decoder = JSONDecoder()
        let imported = try decoder.decode([Prompt].self, from: data)
        print("[PromptStore] Importing \(imported.count) prompts...")
        
        for prompt in imported {
            if !prompts.contains(where: { $0.id == prompt.id }) {
                addPrompt(prompt)
            }
        }
    }
    
    func exportPrompts() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        print("[PromptStore] Exporting \(prompts.count) prompts...")
        return try encoder.encode(prompts)
    }
    
    private func loadPrompts() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else {
            print("[PromptStore] No saved prompts found")
            return
        }
        
        do {
            let decoder = JSONDecoder()
            prompts = try decoder.decode([Prompt].self, from: data)
            print("[PromptStore] Loaded \(prompts.count) prompts from storage")
        } catch {
            print("[PromptStore] Failed to load prompts: \(error)")
        }
    }
    
    private func savePrompts() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(prompts)
            UserDefaults.standard.set(data, forKey: saveKey)
            print("[PromptStore] Saved \(prompts.count) prompts to storage")
        } catch {
            print("[PromptStore] Failed to save prompts: \(error)")
        }
    }
    
    private func loadPreferences() {
        if let placement = UserDefaults.standard.string(forKey: "\(preferencesKey).defaultPlacement"),
           let mode = PlacementMode(rawValue: placement) {
            selectedPlacement = mode
        }
        
        currentAppIdentifier = UserDefaults.standard.string(forKey: "\(preferencesKey).lastApp") ?? ""
        print("[PromptStore] Loaded preferences - placement: \(selectedPlacement.rawValue), app: \(currentAppIdentifier)")
    }
    
    func savePreferences() {
        UserDefaults.standard.set(selectedPlacement.rawValue, forKey: "\(preferencesKey).defaultPlacement")
        UserDefaults.standard.set(currentAppIdentifier, forKey: "\(preferencesKey).lastApp")
        print("[PromptStore] Saved preferences")
    }
}