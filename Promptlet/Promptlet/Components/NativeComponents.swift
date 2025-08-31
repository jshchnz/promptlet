//
//  NativeComponents.swift
//  Promptlet
//
//  Reusable native-feeling components with Apple design language
//

import SwiftUI

// MARK: - Premium Button
struct PremiumButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var isPressed = false
    
    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.xs) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: VisualEffects.buttonCornerRadius)
                    .fill(
                        LinearGradient(
                            colors: [Color.accentColor, Color.accentColor.opacity(0.8)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .shadow(
                        color: Color.accentColor.opacity(isHovered ? 0.3 : 0.15),
                        radius: isHovered ? 12 : 8,
                        y: 4
                    )
            )
            .scaleEffect(isPressed ? VisualEffects.pressScale : (isHovered ? VisualEffects.hoverScale : 1))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(Animation.quick) {
                isHovered = hovering
            }
        }
        .pressEvents(onPress: {
            withAnimation(Animation.quick) {
                isPressed = true
            }
        }, onRelease: {
            withAnimation(Animation.quick) {
                isPressed = false
            }
        })
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let icon: String?
    let subtitle: String?
    
    init(_ title: String, icon: String? = nil, subtitle: String? = nil) {
        self.title = title
        self.icon = icon
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.accent)
                }
                Text(title)
                    .font(Typography.headline())
                    .foregroundColor(.primaryText)
            }
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(Typography.caption())
                    .foregroundColor(.secondaryText)
                    .padding(.leading, icon != nil ? 24 : 0)
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}

// MARK: - Settings Row
struct SettingsRow<Content: View>: View {
    let label: String
    let icon: String?
    let description: String?
    let content: () -> Content
    
    init(_ label: String, 
         icon: String? = nil,
         description: String? = nil,
         @ViewBuilder content: @escaping () -> Content) {
        self.label = label
        self.icon = icon
        self.description = description
        self.content = content
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    HStack(spacing: Spacing.sm) {
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.system(size: 14))
                                .foregroundColor(.accent)
                                .frame(width: 20)
                        }
                        Text(label)
                            .font(Typography.body())
                    }
                    
                    if let description = description {
                        Text(description)
                            .font(Typography.caption())
                            .foregroundColor(.secondaryText)
                            .padding(.leading, icon != nil ? 28 : 0)
                    }
                }
                
                Spacer()
                
                content()
            }
            .padding(.vertical, Spacing.sm)
        }
    }
}

// MARK: - Animated Card
struct AnimatedCard<Content: View>: View {
    let content: () -> Content
    @State private var isHovered = false
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: VisualEffects.cornerRadius)
                    .fill(Color.secondaryBackground)
                    .shadow(
                        color: Color.black.opacity(isHovered ? 0.15 : 0.08),
                        radius: isHovered ? 12 : 6,
                        y: isHovered ? 6 : 3
                    )
            )
            .scaleEffect(isHovered ? 1.02 : 1)
            .onHover { hovering in
                withAnimation(Animation.spring) {
                    isHovered = hovering
                }
            }
    }
}

// MARK: - Progress Dots
struct ProgressDots: View {
    let currentPage: Int
    let totalPages: Int
    
    var body: some View {
        HStack(spacing: Spacing.sm) {
            ForEach(0..<totalPages, id: \.self) { index in
                Circle()
                    .fill(index == currentPage ? Color.accent : Color.tertiaryText.opacity(0.3))
                    .frame(width: 8, height: 8)
                    .scaleEffect(index == currentPage ? 1.2 : 1)
                    .animation(Animation.spring, value: currentPage)
            }
        }
    }
}

// MARK: - Visual Keyboard Key
struct KeyboardKey: View {
    let symbol: String
    let isPressed: Bool
    
    init(_ symbol: String, isPressed: Bool = false) {
        self.symbol = symbol
        self.isPressed = isPressed
    }
    
    var body: some View {
        Text(symbol)
            .font(Typography.monospaced())
            .foregroundColor(isPressed ? .white : .primaryText)
            .frame(minWidth: 32, minHeight: 32)
            .background(
                RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                    .fill(isPressed ? Color.accent : Color.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: VisualEffects.smallCornerRadius)
                            .stroke(Color.divider, lineWidth: 1)
                    )
                    .shadow(
                        color: Color.black.opacity(0.2),
                        radius: 2,
                        y: 1
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1)
            .animation(Animation.quick, value: isPressed)
    }
}

// MARK: - Success Check Animation
struct SuccessCheckmark: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.success.opacity(0.1))
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.2 : 0)
                .opacity(isAnimating ? 1 : 0)
            
            Circle()
                .stroke(Color.success, lineWidth: 3)
                .frame(width: 60, height: 60)
                .scaleEffect(isAnimating ? 1 : 0)
                .opacity(isAnimating ? 1 : 0)
            
            Image(systemName: "checkmark")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.success)
                .scaleEffect(isAnimating ? 1 : 0)
                .rotationEffect(.degrees(isAnimating ? 0 : -30))
        }
        .onAppear {
            withAnimation(Animation.bounce.delay(0.1)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Press Event Modifier
struct PressEvents: ViewModifier {
    let onPress: () -> Void
    let onRelease: () -> Void
    
    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                if pressing {
                    onPress()
                } else {
                    onRelease()
                }
            }, perform: {})
    }
}

extension View {
    func pressEvents(onPress: @escaping () -> Void, onRelease: @escaping () -> Void) -> some View {
        self.modifier(PressEvents(onPress: onPress, onRelease: onRelease))
    }
}