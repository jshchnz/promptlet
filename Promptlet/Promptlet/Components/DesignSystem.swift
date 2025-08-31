//
//  DesignSystem.swift
//  Promptlet
//
//  Design system constants for consistent, Apple-quality UI
//

import SwiftUI

// MARK: - Spacing System
enum Spacing {
    static let xxs: CGFloat = 2
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 20
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Animation System
enum Animation {
    static let spring = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.85)
    static let smooth = SwiftUI.Animation.easeInOut(duration: 0.25)
    static let quick = SwiftUI.Animation.easeOut(duration: 0.15)
    static let bounce = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.65)
    static let gentle = SwiftUI.Animation.easeInOut(duration: 0.35)
}

// MARK: - Visual Effects
struct VisualEffects {
    static let cornerRadius: CGFloat = 10
    static let smallCornerRadius: CGFloat = 6
    static let buttonCornerRadius: CGFloat = 8
    
    static let shadowRadius: CGFloat = 8
    static let shadowOpacity: Double = 0.15
    
    static let hoverScale: CGFloat = 1.02
    static let pressScale: CGFloat = 0.98
}

// MARK: - Typography
struct Typography {
    static func largeTitle() -> Font {
        .system(size: 34, weight: .bold, design: .rounded)
    }
    
    static func title() -> Font {
        .system(size: 28, weight: .semibold, design: .rounded)
    }
    
    static func headline() -> Font {
        .system(size: 17, weight: .semibold, design: .default)
    }
    
    static func body() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }
    
    static func caption() -> Font {
        .system(size: 11, weight: .regular, design: .default)
    }
    
    static func monospaced() -> Font {
        .system(size: 13, weight: .medium, design: .monospaced)
    }
}

// MARK: - Semantic Colors
extension Color {
    static let primaryBackground = Color(NSColor.windowBackgroundColor)
    static let secondaryBackground = Color(NSColor.controlBackgroundColor)
    static let tertiaryBackground = Color(NSColor.unemphasizedSelectedContentBackgroundColor)
    
    static let primaryText = Color(NSColor.labelColor)
    static let secondaryText = Color(NSColor.secondaryLabelColor)
    static let tertiaryText = Color(NSColor.tertiaryLabelColor)
    
    static let divider = Color(NSColor.separatorColor)
    static let accent = Color.accentColor
    
    static let success = Color.green
    static let warning = Color.orange
    static let error = Color.red
}

// MARK: - Layout Constants
struct Layout {
    static let maxSettingsWidth: CGFloat = 680
    static let maxSettingsHeight: CGFloat = 480
    
    static let onboardingWidth: CGFloat = 600
    static let onboardingHeight: CGFloat = 500
    
    static let paletteWidth: CGFloat = 500
    static let paletteHeight: CGFloat = 350
}

// MARK: - Transitions
extension AnyTransition {
    static var slideAndFade: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }
    
    static var scaleAndFade: AnyTransition {
        .scale(scale: 0.95).combined(with: .opacity)
    }
    
    static var smoothSlide: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .top).combined(with: .opacity)
        )
    }
}