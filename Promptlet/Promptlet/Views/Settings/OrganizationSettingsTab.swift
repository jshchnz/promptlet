//
//  OrganizationSettingsTab.swift
//  Promptlet
//
//  Prompt organization and category management
//

import SwiftUI
import UniformTypeIdentifiers

struct OrganizationSettingsTab: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var promptStore: PromptStore
    
    @State private var selectedCategory: String? = nil
    @State private var selectedPromptIds: Set<UUID> = []
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var showingRenameCategory = false
    @State private var renameCategoryName = ""
    @State private var showingDeleteConfirmation = false
    @State private var sortOrder: SortOrder = .manual
    @State private var showArchived = false
    
    @State private var editingPrompt: Prompt?
    @State private var isCreatingNew = false
    
    enum SortOrder: String, CaseIterable {
        case manual = "Manual"
        case name = "Name"
        case dateCreated = "Date Created"
        case lastUsed = "Last Used"
        case usage = "Usage Count"
    }
    
    var displayedPrompts: [Prompt] {
        let prompts: [Prompt]
        if selectedCategory == nil {
            prompts = promptStore.prompts
        } else if selectedCategory == "Uncategorized" {
            prompts = promptStore.promptsInCategory(nil)
        } else {
            prompts = promptStore.promptsInCategory(selectedCategory)
        }
        
        let filtered = showArchived ? prompts : prompts.filter { !$0.isArchived }
        
        switch sortOrder {
        case .manual:
            return filtered.sorted { $0.displayOrder < $1.displayOrder }
        case .name:
            return filtered.sorted { $0.title < $1.title }
        case .dateCreated:
            return filtered.sorted { $0.createdDate > $1.createdDate }
        case .lastUsed:
            return filtered.sorted { $0.lastUsedDate > $1.lastUsedDate }
        case .usage:
            return filtered.sorted { $0.usageCount > $1.usageCount }
        }
    }
    
    var body: some View {
        HStack(spacing: 0) {
            // Sidebar - Categories
            VStack(spacing: 0) {
                List(selection: $selectedCategory) {
                    Label("All Prompts", systemImage: "tray.2")
                        .tag(nil as String?)
                    
                    Label("Uncategorized", systemImage: "folder")
                        .tag("Uncategorized")
                    
                    Section("Categories") {
                        ForEach(promptStore.categories, id: \.self) { category in
                            Label(category, systemImage: "folder.fill")
                                .tag(category as String?)
                                .contextMenu {
                                    Button("Rename...") {
                                        renameCategoryName = category
                                        showingRenameCategory = true
                                    }
                                    Button("Delete", role: .destructive) {
                                        showingDeleteConfirmation = true
                                    }
                                }
                        }
                    }
                }
                .listStyle(.sidebar)
                
                // Category management buttons
                HStack {
                    Button(action: { showingAddCategory = true }) {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    if selectedCategory != nil && selectedCategory != "Uncategorized" {
                        Button(action: {
                            renameCategoryName = selectedCategory!
                            showingRenameCategory = true
                        }) {
                            Image(systemName: "pencil")
                        }
                        .buttonStyle(.plain)
                        
                        Button(action: { showingDeleteConfirmation = true }) {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
            .frame(width: 200)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Main content - Prompt list
            VStack(spacing: 0) {
                // Palette sort mode preference
                HStack {
                    Text("Palette Sort Mode:")
                        .font(.caption)
                    
                    Picker("", selection: $promptStore.paletteSortMode) {
                        ForEach(PaletteSortMode.allCases, id: \.self) { mode in
                            Label(mode.displayName, systemImage: mode.icon)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 150)
                    .onChange(of: promptStore.paletteSortMode) {
                        promptStore.savePreferences()
                    }
                    
                    Text(promptStore.paletteSortMode == .smart ? 
                         "Sorts by usage frequency and recency" : 
                         "Uses your custom drag-and-drop order")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
                
                Divider()
                
                // Toolbar
                HStack {
                    // Bulk actions
                    if !selectedPromptIds.isEmpty {
                        Button("Move to...") {
                            // Show category picker
                        }
                        .controlSize(.small)
                        
                        Button(showArchived ? "Unarchive" : "Archive") {
                            if showArchived {
                                promptStore.unarchivePrompts(selectedPromptIds)
                            } else {
                                promptStore.archivePrompts(selectedPromptIds)
                            }
                            selectedPromptIds.removeAll()
                        }
                        .controlSize(.small)
                        
                        Button("Delete", role: .destructive) {
                            for id in selectedPromptIds {
                                if let prompt = promptStore.prompts.first(where: { $0.id == id }) {
                                    promptStore.deletePrompt(prompt)
                                }
                            }
                            selectedPromptIds.removeAll()
                        }
                        .controlSize(.small)
                        
                        Text("\(selectedPromptIds.count) selected")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    // New Prompt button
                    Button("New Prompt") {
                        let newPrompt = Prompt(
                            title: "New Prompt",
                            content: "",
                            category: selectedCategory == "Uncategorized" ? nil : selectedCategory
                        )
                        editingPrompt = newPrompt
                        isCreatingNew = true
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                    
                    Spacer()
                        .frame(width: 12)
                    
                    // View options
                    Toggle("Show Archived", isOn: $showArchived)
                        .toggleStyle(.checkbox)
                        .controlSize(.small)
                    
                    Picker("Sort by", selection: $sortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.menu)
                    .controlSize(.small)
                    .frame(width: 120)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))
                
                Divider()
                
                // Prompt table
                VStack(spacing: 0) {
                    // Table header
                    HStack {
                        if sortOrder == .manual {
                            Text("")
                                .frame(width: 30)
                        }
                        Text("Select")
                            .frame(width: 50, alignment: .leading)
                        Text("Title")
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("Category")
                            .frame(width: 100, alignment: .leading)
                        Text("Tags")
                            .frame(width: 150, alignment: .leading)
                        Text("Usage")
                            .frame(width: 60, alignment: .trailing)
                        Text("Edit")
                            .frame(width: 30, alignment: .center)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(NSColor.controlBackgroundColor))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    Divider()
                    
                    // Prompt rows - use List for drag and drop support
                    if sortOrder == .manual {
                        // Manual sorting with drag and drop
                        List {
                            ForEach(displayedPrompts) { prompt in
                                PromptOrganizationRow(
                                    prompt: prompt,
                                    isSelected: selectedPromptIds.contains(prompt.id),
                                    onToggle: {
                                        if selectedPromptIds.contains(prompt.id) {
                                            selectedPromptIds.remove(prompt.id)
                                        } else {
                                            selectedPromptIds.insert(prompt.id)
                                        }
                                    },
                                    onEdit: {
                                        editingPrompt = prompt
                                        isCreatingNew = false
                                    },
                                    promptStore: promptStore,
                                    showDragHandle: true
                                )
                                .listRowInsets(EdgeInsets())
                                .listRowSeparator(.hidden)
                                .listRowBackground(
                                    selectedPromptIds.contains(prompt.id) ? 
                                    Color.accentColor.opacity(0.1) : Color.clear
                                )
                            }
                            .onMove(perform: movePrompts)
                            .onInsert(of: [.plainText]) { index, providers in
                                // Empty implementation to prevent macOS drag issues
                            }
                        }
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .background(Color.clear)
                    } else {
                        // Other sort modes without drag and drop
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(displayedPrompts) { prompt in
                                    PromptOrganizationRow(
                                        prompt: prompt,
                                        isSelected: selectedPromptIds.contains(prompt.id),
                                        onToggle: {
                                            if selectedPromptIds.contains(prompt.id) {
                                                selectedPromptIds.remove(prompt.id)
                                            } else {
                                                selectedPromptIds.insert(prompt.id)
                                            }
                                        },
                                        onEdit: {
                                            editingPrompt = prompt
                                            isCreatingNew = false
                                        },
                                        promptStore: promptStore,
                                        showDragHandle: false
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddCategory) {
            AddCategorySheet(
                categoryName: $newCategoryName,
                onAdd: {
                    promptStore.addCategory(newCategoryName)
                    newCategoryName = ""
                    showingAddCategory = false
                },
                onCancel: {
                    newCategoryName = ""
                    showingAddCategory = false
                }
            )
        }
        .sheet(isPresented: $showingRenameCategory) {
            RenameCategorySheet(
                oldName: selectedCategory ?? "",
                newName: $renameCategoryName,
                onRename: {
                    if let selected = selectedCategory {
                        promptStore.renameCategory(from: selected, to: renameCategoryName)
                        selectedCategory = renameCategoryName
                    }
                    renameCategoryName = ""
                    showingRenameCategory = false
                },
                onCancel: {
                    renameCategoryName = ""
                    showingRenameCategory = false
                }
            )
        }
        .alert("Delete Category", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let selected = selectedCategory, selected != "Uncategorized" {
                    promptStore.removeCategory(selected)
                    selectedCategory = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete '\(selectedCategory ?? "")'? Prompts in this category will become uncategorized.")
        }
        .sheet(item: $editingPrompt) { prompt in
            PromptEditorView(
                prompt: prompt,
                onSave: { updatedPrompt in
                    if isCreatingNew {
                        var newPrompt = updatedPrompt
                        newPrompt.category = selectedCategory == "Uncategorized" ? nil : selectedCategory
                        promptStore.addPrompt(newPrompt)
                    } else {
                        promptStore.updatePrompt(updatedPrompt)
                    }
                    editingPrompt = nil
                },
                onCancel: {
                    editingPrompt = nil
                }
            )
        }
        .onKeyPress(.return) {
            if selectedPromptIds.count == 1,
               let promptId = selectedPromptIds.first,
               let prompt = promptStore.prompts.first(where: { $0.id == promptId }) {
                editingPrompt = prompt
                isCreatingNew = false
                return .handled
            }
            return .ignored
        }
    }
    
    private func movePrompts(from source: IndexSet, to destination: Int) {
        print("movePrompts called - from: \(source), to: \(destination)")
        
        // Get the actual prompts array we're displaying
        var movedPrompts = displayedPrompts
        
        // Perform the move in our local copy
        movedPrompts.move(fromOffsets: source, toOffset: destination)
        
        // Update the displayOrder for each moved prompt
        for (index, prompt) in movedPrompts.enumerated() {
            if let globalIndex = promptStore.prompts.firstIndex(where: { $0.id == prompt.id }) {
                promptStore.prompts[globalIndex].displayOrder = index
            }
        }
        
        // Trigger store update
        promptStore.objectWillChange.send()
    }
}

struct PromptOrganizationRow: View {
    let prompt: Prompt
    let isSelected: Bool
    let onToggle: () -> Void
    let onEdit: () -> Void
    @ObservedObject var promptStore: PromptStore
    var showDragHandle: Bool = false
    @State private var showingCategoryMenu = false
    
    var body: some View {
        HStack(spacing: 0) {
            if showDragHandle {
                Image(systemName: "line.3.horizontal")
                    .foregroundColor(.secondary)
                    .frame(width: 30)
                    .padding(.leading, 12)
            }
            
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .frame(width: 50)
            .padding(.leading, showDragHandle ? 0 : 12)
            
            Text(prompt.title)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(prompt.isArchived ? 0.5 : 1)
            
            Menu {
                Button("None") {
                    updateCategory(nil)
                }
                Divider()
                ForEach(promptStore.categories, id: \.self) { category in
                    Button(category) {
                        updateCategory(category)
                    }
                }
            } label: {
                Text(prompt.category ?? "Uncategorized")
                    .lineLimit(1)
                    .frame(width: 100, alignment: .leading)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            
            Text(Array(prompt.tags).joined(separator: ", "))
                .lineLimit(1)
                .frame(width: 150, alignment: .leading)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text("\(prompt.usageCount)")
                .frame(width: 60, alignment: .trailing)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Button(action: onEdit) {
                Image(systemName: "pencil")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 30)
            .help("Edit Prompt")
        }
        .padding(.trailing, 12)
        .padding(.leading, showDragHandle ? 0 : 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
        .onTapGesture(count: 2) {
            onEdit()
        }
        .contextMenu {
            Button("Edit") {
                onEdit()
            }
            
            Divider()
            
            Button(prompt.isFavorite ? "Remove from Favorites" : "Add to Favorites") {
                var updatedPrompt = prompt
                updatedPrompt.isFavorite.toggle()
                promptStore.updatePrompt(updatedPrompt)
            }
            
            Button("Duplicate") {
                promptStore.duplicatePrompt(prompt)
            }
            
            Divider()
            
            Button(prompt.isArchived ? "Unarchive" : "Archive") {
                var updatedPrompt = prompt
                updatedPrompt.isArchived.toggle()
                promptStore.updatePrompt(updatedPrompt)
            }
            
            Button("Delete", role: .destructive) {
                promptStore.deletePrompt(prompt)
            }
        }
    }
    
    private func updateCategory(_ category: String?) {
        var updatedPrompt = prompt
        updatedPrompt.category = category
        promptStore.updatePrompt(updatedPrompt)
    }
}

struct AddCategorySheet: View {
    @Binding var categoryName: String
    let onAdd: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Category")
                .font(.headline)
            
            TextField("Category Name", text: $categoryName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                
                Button("Add", action: onAdd)
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}

struct RenameCategorySheet: View {
    let oldName: String
    @Binding var newName: String
    let onRename: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Rename Category")
                .font(.headline)
            
            TextField("New Name", text: $newName)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            
            HStack {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.escape)
                
                Button("Rename", action: onRename)
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}