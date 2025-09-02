//
//  OrganizationSettingsTab.swift
//  Promptlet
//
//  Prompt organization and category management
//

import SwiftUI

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
    @State private var sortOrder: SortOrder = .name
    @State private var showArchived = false
    
    enum SortOrder: String, CaseIterable {
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
                ScrollView {
                    VStack(spacing: 0) {
                        // Table header
                        HStack {
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
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        
                        Divider()
                        
                        // Prompt rows
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
                                promptStore: promptStore
                            )
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
    }
}

struct PromptOrganizationRow: View {
    let prompt: Prompt
    let isSelected: Bool
    let onToggle: () -> Void
    @ObservedObject var promptStore: PromptStore
    @State private var showingCategoryMenu = false
    
    var body: some View {
        HStack {
            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { _ in onToggle() }
            ))
            .toggleStyle(.checkbox)
            .frame(width: 50)
            
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
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            onToggle()
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