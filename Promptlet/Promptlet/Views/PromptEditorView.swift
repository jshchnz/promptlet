//
//  PromptEditorView.swift
//  Promptlet
//
//  Created by Assistant on 8/30/25.
//

import SwiftUI

struct PromptEditorView: View {
    @State private var title: String
    @State private var content: String
    @State private var tags: String
    @State private var placementMode: PlacementMode
    @FocusState private var isTitleFocused: Bool
    
    let originalPrompt: Prompt
    let onSave: (Prompt) -> Void
    let onCancel: () -> Void
    
    init(prompt: Prompt, onSave: @escaping (Prompt) -> Void, onCancel: @escaping () -> Void) {
        self.originalPrompt = prompt
        self.onSave = onSave
        self.onCancel = onCancel
        
        // Initialize state with prompt values
        _title = State(initialValue: prompt.title)
        _content = State(initialValue: prompt.content)
        _tags = State(initialValue: Array(prompt.tags).joined(separator: ", "))
        _placementMode = State(initialValue: prompt.defaultEnhancement.placement)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 15) {
                HStack {
                    Text("Edit Prompt")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                }
                
                // Title field
                VStack(alignment: .leading, spacing: 5) {
                    Text("Title")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("Prompt title", text: $title)
                        .textFieldStyle(.roundedBorder)
                        .focused($isTitleFocused)
                }
                
                // Content field
                VStack(alignment: .leading, spacing: 5) {
                    Text("Content")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextEditor(text: $content)
                        .font(.system(.body, design: .monospaced))
                        .frame(minHeight: 150, maxHeight: 250)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                        )
                }
                
                // Tags field
                VStack(alignment: .leading, spacing: 5) {
                    Text("Tags (comma-separated)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("tag1, tag2, tag3", text: $tags)
                        .textFieldStyle(.roundedBorder)
                }
                
                // Enhancement options
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Placement")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Picker("", selection: $placementMode) {
                        ForEach(PlacementMode.allCases, id: \.self) { mode in
                            Text(mode.description).tag(mode)
                        }
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }
            .padding(20)
            
            Divider()
            
            // Buttons
            HStack {
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.escape, modifiers: [])
                
                Spacer()
                
                Button("Save") {
                    savePrompt()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(15)
        }
        .frame(width: 500, height: 550)
        .background(VisualEffectView())
        .onAppear {
            isTitleFocused = true
        }
    }
    
    private func savePrompt() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        
        let tagArray = tags
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let tagSet = Set(tagArray)
        
        let enhancement = Enhancement(placement: placementMode)
        
        let updatedPrompt = Prompt(
            id: originalPrompt.id,
            title: trimmedTitle,
            content: content,
            tags: tagSet,
            defaultEnhancement: enhancement,
            variables: originalPrompt.variables,
            isFavorite: originalPrompt.isFavorite,
            quickSlot: originalPrompt.quickSlot,
            createdDate: originalPrompt.createdDate,
            lastUsedDate: originalPrompt.lastUsedDate,
            usageCount: originalPrompt.usageCount,
            perAppEnhancements: originalPrompt.perAppEnhancements
        )
        
        onSave(updatedPrompt)
    }
}