//
//  PaletteView.swift
//  Promptlet
//
//  Main command palette interface for searching and selecting prompts
//

import SwiftUI

struct PaletteView: View {
    @ObservedObject var store: PromptStore
    @ObservedObject var controller: PaletteController
    @ObservedObject var appSettings: AppSettings
    let onInsert: (Prompt) -> Void
    let onDismiss: () -> Void
    let onNewPrompt: (() -> Void)?
    @FocusState private var isSearchFocused: Bool
    
    init(store: PromptStore,
         controller: PaletteController,
         appSettings: AppSettings,
         onInsert: @escaping (Prompt) -> Void,
         onDismiss: @escaping () -> Void,
         onNewPrompt: (() -> Void)? = nil) {
        self.store = store
        self.controller = controller
        self.appSettings = appSettings
        self.onInsert = onInsert
        self.onDismiss = onDismiss
        self.onNewPrompt = onNewPrompt
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Type to search...", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
                    .onChange(of: store.searchText) { _, newValue in
                        if !newValue.isEmpty && newValue.count >= 2 {
                            trackAnalytics(.searchPerformed, properties: [
                                "query_length": newValue.count,
                                "results_count": store.filteredPrompts.count
                            ])
                        }
                    }
                    .onSubmit {
                        if let prompt = controller.getCurrentPrompt() {
                            onInsert(prompt)
                        }
                    }
                
                if !store.searchText.isEmpty {
                    Button(action: { store.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Divider()
                    .frame(height: 16)
                
                // Sort mode toggle
                Button(action: {
                    let newMode = store.paletteSortMode == .smart ? PaletteSortMode.manual : PaletteSortMode.smart
                    trackAnalytics(.sortModeChanged, properties: [
                        "old_mode": store.paletteSortMode.rawValue,
                        "new_mode": newMode.rawValue
                    ])
                    store.paletteSortMode = newMode
                    store.savePreferences()
                }) {
                    Image(systemName: store.paletteSortMode.icon)
                        .foregroundColor(store.paletteSortMode == .manual ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Sort mode: \(store.paletteSortMode.displayName) - Click to toggle between Smart (frecency) and Manual ordering")
            }
            .padding(12)
            
            Divider()
            
            // Content area - either prompt list or empty state
            if store.filteredPrompts.isEmpty {
                // Empty state
                VStack(spacing: 20) {
                    Spacer()
                    
                    if store.prompts.isEmpty {
                        // No prompts exist at all
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Prompts Yet")
                            .font(.headline)
                        
                        Text("Create your first prompt to get started")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        if let onNewPrompt = onNewPrompt {
                            Button("Create New Prompt") {
                                onNewPrompt()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            
                            if let shortcut = appSettings.getShortcut(for: .newPrompt) {
                                Text("or press \(shortcut.displayString)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else if !store.searchText.isEmpty {
                        // Search returned no results
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        
                        Text("No Results")
                            .font(.headline)
                        
                        Text("No prompts match \"\(store.searchText)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Clear Search") {
                            store.searchText = ""
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        
                        if onNewPrompt != nil,
                           let shortcut = appSettings.getShortcut(for: .newPrompt) {
                            Text("Press \(shortcut.displayString) to create a new prompt")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Prompt list
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 1) {
                            ForEach(Array(store.filteredPrompts.enumerated()), id: \.element.id) { index, prompt in
                                SimplePromptRow(
                                    prompt: prompt,
                                    isSelected: index == controller.selectedIndex
                                )
                                .background(
                                    ClickableRow(
                                        onSingleClick: {
                                            controller.selectPrompt(at: index)
                                        },
                                        onDoubleClick: {
                                            onInsert(prompt)
                                        }
                                    )
                                )
                                .id(prompt.id)
                            }
                        }
                        .padding(4)
                    }
                    .onChange(of: controller.selectedIndex) { _, newIndex in
                        if newIndex < store.filteredPrompts.count {
                            let prompt = store.filteredPrompts[newIndex]
                            withAnimation(.easeInOut(duration: 0.15)) {
                                proxy.scrollTo(prompt.id, anchor: .center)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // Footer
            HStack {
                // Dynamic shortcuts display
                if let upShortcut = appSettings.getShortcut(for: .navigateUp),
                   let downShortcut = appSettings.getShortcut(for: .navigateDown) {
                    Text("\(upShortcut.displayString)/\(downShortcut.displayString) Navigate")
                }
                
                if let insertShortcut = appSettings.getShortcut(for: .insertPrompt) {
                    Text("•")
                    Text("\(insertShortcut.displayString) Insert")
                }
                
                if let newShortcut = appSettings.getShortcut(for: .newPrompt) {
                    Text("•")
                    Text("\(newShortcut.displayString) New")
                }
                
                if let closeShortcut = appSettings.getShortcut(for: .closePalette) {
                    Text("•")
                    Text("\(closeShortcut.displayString) Close")
                }
                
                Spacer()
                
                Text("\(store.filteredPrompts.count) prompts")
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding(8)
        }
        .frame(width: 500, height: 350)
        .background(VisualEffectBackground(material: .popover, state: .followsWindowActiveState))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.2), radius: 15, x: 0, y: 5)
        .onAppear {
            controller.reset()
            isSearchFocused = true
        }
    }
}

struct SimplePromptRow: View {
    let prompt: Prompt
    let isSelected: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(prompt.title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
                
                if !prompt.content.isEmpty {
                    Text(prompt.content)
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
                        .lineLimit(2)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            
            Spacer()
            
            if prompt.variables.isEmpty {
                Image(systemName: "text.cursor")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? .white : .secondary)
            } else {
                Text("\(prompt.variables.count)")
                    .font(.system(size: 10))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.2))
                    .cornerRadius(3)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 5)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

