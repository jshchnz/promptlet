//
//  QuickSlotsSetupPage.swift
//  Promptlet
//
//  Setup first quick slots during onboarding
//

import SwiftUI

struct QuickSlotsSetupPage: View {
    @ObservedObject var promptStore: PromptStore
    @ObservedObject var settings: AppSettings
    @State private var selectedPrompt: Prompt?
    @State private var showSuccess = false
    @State private var animateSlots = false
    @State private var showCreatePrompt = false
    @State private var newPromptTitle = ""
    @State private var newPromptContent = ""
    
    // Recommended prompts for first quick slot (3 most versatile)
    private let recommendedPrompts: [Prompt] = [
        Prompt.samplePrompts[0], // Ultrathink
        Prompt.samplePrompts[1], // Step-by-Step
        Prompt.samplePrompts[2]  // Deep Analysis
    ]
    
    private var hasSelectedPrompt: Bool {
        selectedPrompt != nil
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Top spacing - 20px
            Spacer()
                .frame(height: 20)
            
            // Header icon and title - ~60px
            VStack(spacing: 12) {
                // Animated keyboard icon
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [Color.accent.opacity(0.1), Color.accent.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 50, height: 50)
                    
                    Image(systemName: "keyboard")
                        .font(.system(size: 24))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.accent, Color.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .scaleEffect(animateSlots ? 1.1 : 1.0)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        animateSlots = true
                    }
                }
                
                VStack(spacing: 4) {
                    Text(hasSelectedPrompt ? "Quick Slot Ready!" : "Set up Your First Quick Slot")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(hasSelectedPrompt ? "Your most important prompt, one keypress away" : "Choose your most important prompt for ⌘1")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            
            // Spacing - 25px
            Spacer()
                .frame(height: 25)
            
            // Quick slot setup section - ~200px
            VStack(spacing: 20) {
                // Single keyboard shortcut preview
                QuickSlotPreview(
                    slot: 1,
                    assignedPrompt: selectedPrompt,
                    isAssigned: selectedPrompt != nil
                )
                
                // Recommended prompts selection
                if !hasSelectedPrompt {
                    VStack(spacing: 12) {
                        Text("Choose your first quick slot:")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primaryText)
                        
                        VStack(spacing: 8) {
                            ForEach(recommendedPrompts, id: \.id) { prompt in
                                RecommendedPromptRow(
                                    prompt: prompt,
                                    slotNumber: 1,
                                    isSelected: selectedPrompt?.id == prompt.id,
                                    onSelect: {
                                        selectedPrompt = prompt
                                        showCreatePrompt = false
                                    }
                                )
                            }
                            
                            // Create New Prompt Option
                            CreateNewPromptRow(
                                isSelected: showCreatePrompt,
                                onSelect: {
                                    showCreatePrompt = true
                                    selectedPrompt = nil
                                }
                            )
                        }
                    }
                }
                
                // Create new prompt form
                if showCreatePrompt {
                    VStack(spacing: 12) {
                        Text("Create Your Quick Slot Prompt")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primaryText)
                        
                        VStack(spacing: 8) {
                            TextField("Prompt title (e.g., \"My Custom Prompt\")", text: $newPromptTitle)
                                .textFieldStyle(.roundedBorder)
                            
                            TextField("Prompt content (e.g., \"Think about this carefully.\")", text: $newPromptContent, axis: .vertical)
                                .textFieldStyle(.roundedBorder)
                                .lineLimit(2...4)
                        }
                        
                        HStack(spacing: 12) {
                            Button("Cancel") {
                                showCreatePrompt = false
                                newPromptTitle = ""
                                newPromptContent = ""
                            }
                            .buttonStyle(.plain)
                            .foregroundColor(.secondaryText)
                            
                            Button("Create Prompt") {
                                createCustomPrompt()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newPromptTitle.isEmpty || newPromptContent.isEmpty)
                        }
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondaryBackground.opacity(0.3))
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
                
                // Success state
                if hasSelectedPrompt && !showCreatePrompt {
                    VStack(spacing: 12) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.success)
                            Text("Try pressing ⌘1 anytime!")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.success)
                        }
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            
            // Spacing - 20px  
            Spacer()
                .frame(height: 20)
            
            // Footer hint - ~30px
            VStack(spacing: 8) {
                if !hasSelectedPrompt {
                    Text("Click any prompt above to assign it to your first quick slot")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Add more quick slots (2-9) anytime in Settings")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                        .multilineTextAlignment(.center)
                }
                
                Text("You can change this anytime in Settings")
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryText)
                    .opacity(0.8)
            }
            
            // Bottom spacing - 25px
            Spacer()
                .frame(height: 25)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: hasSelectedPrompt)
        .onDisappear {
            applySelection()
        }
    }
    
    private func createCustomPrompt() {
        let newPrompt = Prompt(
            title: newPromptTitle.trimmingCharacters(in: .whitespacesAndNewlines),
            content: newPromptContent.trimmingCharacters(in: .whitespacesAndNewlines),
            tags: ["custom", "quick-slot"],
            defaultEnhancement: Enhancement(placement: .cursor),
            quickSlot: 1
        )
        
        // Add to prompt store
        promptStore.addPrompt(newPrompt)
        
        // Select the new prompt
        selectedPrompt = newPrompt
        showCreatePrompt = false
        
        // Clear form
        newPromptTitle = ""
        newPromptContent = ""
    }
    
    
    private func applySelection() {
        // Apply the selected prompt to slot 1 in the actual prompt store
        guard let selectedPrompt = selectedPrompt else { return }
        
        // Find the prompt in the store and update it
        if let storePrompt = promptStore.prompts.first(where: { $0.title == selectedPrompt.title }) {
            let updatedPrompt = Prompt(
                id: storePrompt.id,
                title: storePrompt.title,
                content: storePrompt.content,
                tags: storePrompt.tags,
                category: storePrompt.category,
                defaultEnhancement: storePrompt.defaultEnhancement,
                variables: storePrompt.variables,
                isFavorite: storePrompt.isFavorite,
                isArchived: storePrompt.isArchived,
                quickSlot: 1,
                createdDate: storePrompt.createdDate,
                lastUsedDate: storePrompt.lastUsedDate,
                usageCount: storePrompt.usageCount,
                perAppEnhancements: storePrompt.perAppEnhancements,
                displayOrder: storePrompt.displayOrder
            )
            promptStore.updatePrompt(updatedPrompt)
        }
    }
}

// Preview component for keyboard shortcuts
struct QuickSlotPreview: View {
    let slot: Int
    let assignedPrompt: Prompt?
    let isAssigned: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Keyboard shortcut
            HStack(spacing: 2) {
                Text("⌘")
                    .font(.system(size: 14, weight: .medium))
                Text("\(slot)")
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isAssigned ? Color.accent : Color.gray.opacity(0.4))
            )
            
            // Prompt preview
            VStack(spacing: 2) {
                if let prompt = assignedPrompt {
                    Text(prompt.title)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    Text(prompt.preview)
                        .font(.system(size: 9))
                        .foregroundColor(.secondaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Empty")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                    Text("Not assigned")
                        .font(.system(size: 9))
                        .foregroundColor(.tertiaryText)
                }
            }
            .frame(width: 100, height: 35)
        }
    }
}

// Individual prompt selection row
struct RecommendedPromptRow: View {
    let prompt: Prompt
    let slotNumber: Int
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Slot indicator
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accent : Color.gray.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Text("\(slotNumber)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondaryText)
                }
                
                // Prompt info
                VStack(alignment: .leading, spacing: 2) {
                    Text(prompt.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Text(prompt.preview)
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Keyboard shortcut preview
                HStack(spacing: 2) {
                    Text("⌘\(slotNumber)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.tertiaryText)
                }
                .opacity(isSelected ? 1 : 0.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accent.opacity(0.1) : (isHovered ? Color.gray.opacity(0.05) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .disabled(isSelected)
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

// Create new prompt option row
struct CreateNewPromptRow: View {
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovered = false
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Plus icon
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.accent : Color.gray.opacity(0.2))
                        .frame(width: 24, height: 24)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .secondaryText)
                }
                
                // Prompt info
                VStack(alignment: .leading, spacing: 2) {
                    Text("Create New Prompt")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primaryText)
                        .lineLimit(1)
                    
                    Text("Write your own custom prompt")
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Keyboard shortcut preview
                HStack(spacing: 2) {
                    Text("⌘1")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.tertiaryText)
                }
                .opacity(isSelected ? 1 : 0.5)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accent.opacity(0.1) : (isHovered ? Color.gray.opacity(0.05) : Color.clear))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? Color.accent.opacity(0.3) : Color.clear, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .animation(.easeOut(duration: 0.15), value: isSelected)
        .animation(.easeOut(duration: 0.15), value: isHovered)
    }
}

#Preview {
    QuickSlotsSetupPage(
        promptStore: PromptStore(),
        settings: AppSettings()
    )
    .frame(width: 760, height: 450)
}