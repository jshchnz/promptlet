//
//  PaletteController.swift
//  Promptlet
//
//  Created by Josh Cohenzadeh on 8/29/25.
//

import SwiftUI
import AppKit

@MainActor
class PaletteController: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var isVisible: Bool = false
    
    weak var store: PromptStore?
    weak var window: NSWindow?
    
    init(store: PromptStore) {
        self.store = store
    }
    
    func navigateUp() {
        guard let store = store else { return }
        let prompts = store.filteredPrompts
        guard !prompts.isEmpty else { return }
        
        selectedIndex = max(0, selectedIndex - 1)
        print("[PaletteController] Navigate up to: \(selectedIndex)")
    }
    
    func navigateDown() {
        guard let store = store else { return }
        let prompts = store.filteredPrompts
        guard !prompts.isEmpty else { return }
        
        selectedIndex = min(prompts.count - 1, selectedIndex + 1)
        print("[PaletteController] Navigate down to: \(selectedIndex)")
    }
    
    func selectPrompt(at index: Int) {
        selectedIndex = index
    }
    
    func getCurrentPrompt() -> Prompt? {
        guard let store = store else { return nil }
        let prompts = store.filteredPrompts
        guard selectedIndex < prompts.count else { return nil }
        return prompts[selectedIndex]
    }
    
    func reset() {
        selectedIndex = 0
        isVisible = true
    }
    
    func hide() {
        isVisible = false
    }
}