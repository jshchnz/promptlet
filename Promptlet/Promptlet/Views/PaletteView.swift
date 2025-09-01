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
    @FocusState private var isSearchFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("Type to search...", text: $store.searchText)
                    .textFieldStyle(.plain)
                    .focused($isSearchFocused)
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
            }
            .padding(12)
            
            Divider()
            
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
                                DoubleClickableRow(
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
        .background(VisualEffectView())
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
                    Text(prompt.content.prefix(50))
                        .font(.system(size: 11))
                        .foregroundColor(isSelected ? Color.white.opacity(0.8) : .secondary)
                        .lineLimit(1)
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

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        // Use popover material for better blur effect like Spotlight
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        view.wantsLayer = true
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        // Update state if needed
        nsView.state = .followsWindowActiveState
    }
}