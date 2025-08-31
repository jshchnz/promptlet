//
//  ModernAppearanceTab.swift
//  Promptlet
//
//  Beautiful appearance settings with live preview
//

import SwiftUI

struct ModernAppearanceTab: View {
    @ObservedObject var settings: AppSettings
    @State private var previewTheme: ThemeMode = .auto
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.xl) {
                // Theme Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader("Theme", icon: "circle.lefthalf.filled")
                    
                    VStack(spacing: Spacing.lg) {
                        // Theme selector with preview
                        HStack(spacing: Spacing.md) {
                            ForEach(ThemeMode.allCases, id: \.rawValue) { mode in
                                ThemeCard(
                                    mode: mode,
                                    isSelected: settings.themeMode == mode.rawValue,
                                    action: {
                                        withAnimation(Animation.spring) {
                                            settings.themeMode = mode.rawValue
                                            previewTheme = mode
                                        }
                                    }
                                )
                            }
                        }
                        
                        // Live preview
                        ThemePreview(theme: previewTheme)
                            .transition(.opacity)
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                            .fill(Color.secondaryBackground.opacity(0.5))
                    )
                }
                
                // Visual Effects Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader("Visual Effects", icon: "sparkles")
                    
                    VStack(spacing: Spacing.md) {
                        SettingsRow("Window Animations", icon: "play.circle") {
                            Toggle("", isOn: $settings.enableAnimations)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        
                        if settings.enableAnimations {
                            SettingsRow("Animation Speed", icon: "speedometer") {
                                AnimationSpeedPicker()
                            }
                            .transition(.opacity)
                        }
                        
                        Divider()
                        
                        SettingsRow("Menu Bar Icon", icon: "menubar.rectangle") {
                            Toggle("", isOn: $settings.showMenuBarIcon)
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        
                        SettingsRow("Window Transparency", icon: "square.on.square") {
                            TransparencySlider()
                        }
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                            .fill(Color.secondaryBackground.opacity(0.5))
                    )
                }
                
                // Accessibility Section
                VStack(alignment: .leading, spacing: Spacing.md) {
                    SectionHeader("Accessibility", icon: "accessibility")
                    
                    VStack(spacing: Spacing.md) {
                        SettingsRow("Reduce Motion", icon: "figure.walk.motion") {
                            Toggle("", isOn: .constant(false))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                        
                        SettingsRow("High Contrast", icon: "circle.lefthalf.striped.horizontal") {
                            Toggle("", isOn: .constant(false))
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }
                    }
                    .padding(Spacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                            .fill(Color.secondaryBackground.opacity(0.5))
                    )
                }
            }
            .padding(Spacing.lg)
        }
        .onAppear {
            previewTheme = settings.theme
        }
    }
}

// MARK: - Theme Card
struct ThemeCard: View {
    let mode: ThemeMode
    let isSelected: Bool
    let action: () -> Void
    
    @State private var isHovered = false
    
    var icon: String {
        switch mode {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        case .auto:
            return "circle.lefthalf.filled"
        }
    }
    
    var colors: [Color] {
        switch mode {
        case .light:
            return [Color.white, Color.gray.opacity(0.1)]
        case .dark:
            return [Color.black, Color.gray.opacity(0.8)]
        case .auto:
            return [Color.white, Color.black]
        }
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                        .fill(
                            LinearGradient(
                                colors: colors,
                                startPoint: mode == .auto ? .leading : .top,
                                endPoint: mode == .auto ? .trailing : .bottom
                            )
                        )
                        .frame(width: 100, height: 70)
                        .overlay(
                            RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                                .stroke(
                                    isSelected ? Color.accent : Color.divider,
                                    lineWidth: isSelected ? 3 : 1
                                )
                        )
                        .shadow(
                            color: Color.black.opacity(isHovered ? 0.2 : 0.1),
                            radius: isHovered ? 8 : 4,
                            y: 2
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 24))
                        .foregroundColor(mode == .dark ? .white : (mode == .light ? .black : .accent))
                }
                
                Text(mode.rawValue)
                    .font(Typography.body())
                    .foregroundColor(isSelected ? .accent : .primaryText)
            }
            .scaleEffect(isHovered ? 1.05 : 1)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Animation.spring) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Theme Preview
struct ThemePreview: View {
    let theme: ThemeMode
    
    var backgroundColor: Color {
        switch theme {
        case .light:
            return Color.white
        case .dark:
            return Color.black
        case .auto:
            return Color.primaryBackground
        }
    }
    
    var textColor: Color {
        switch theme {
        case .light:
            return Color.black
        case .dark:
            return Color.white
        case .auto:
            return Color.primaryText
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("Preview")
                .font(Typography.caption())
                .foregroundColor(.tertiaryText)
            
            // Mini palette preview
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 10))
                    Text("Search...")
                        .font(.system(size: 10))
                    Spacer()
                }
                .foregroundColor(textColor.opacity(0.5))
                .padding(Spacing.xs)
                .background(backgroundColor.opacity(0.1))
                
                Divider()
                
                // Prompt items
                VStack(spacing: 2) {
                    ForEach(0..<3) { index in
                        HStack {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(textColor.opacity(index == 0 ? 0.8 : 0.3))
                                .frame(width: 60, height: 4)
                            Spacer()
                        }
                        .padding(.vertical, Spacing.xs)
                        .padding(.horizontal, Spacing.sm)
                        .background(index == 0 ? Color.accent.opacity(0.1) : Color.clear)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }
            .background(
                RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                    .fill(backgroundColor)
                    .overlay(
                        RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                            .stroke(Color.divider, lineWidth: 1)
                    )
            )
            .frame(height: 100)
        }
    }
}

// MARK: - Animation Speed Picker
struct AnimationSpeedPicker: View {
    @State private var speed: Double = 1.0
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "tortoise.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
            
            Slider(value: $speed, in: 0.5...2.0)
                .frame(width: 120)
            
            Image(systemName: "hare.fill")
                .font(.system(size: 12))
                .foregroundColor(.secondaryText)
        }
    }
}

// MARK: - Transparency Slider
struct TransparencySlider: View {
    @State private var transparency: Double = 0.95
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            Text("\(Int(transparency * 100))%")
                .font(Typography.monospaced())
                .foregroundColor(.secondaryText)
                .frame(width: 40)
            
            Slider(value: $transparency, in: 0.5...1.0)
                .frame(width: 120)
        }
    }
}