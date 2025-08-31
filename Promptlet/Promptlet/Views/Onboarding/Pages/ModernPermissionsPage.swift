//
//  ModernPermissionsPage.swift
//  Promptlet
//
//  Beautiful permissions request with clear explanations
//

import SwiftUI

struct ModernPermissionsPage: View {
    @ObservedObject var permissionManager: PermissionManager
    @State private var checkingPermissions = false
    @State private var animateShield = false
    @State private var showCards = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top section - 100px
            VStack(spacing: 12) {
                // Animated shield icon
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    Color.accent.opacity(0.3),
                                    Color.accent.opacity(0.1),
                                    Color.clear
                                ],
                                center: .center,
                                startRadius: 10,
                                endRadius: 40
                            )
                        )
                        .frame(width: 80, height: 80)
                        .scaleEffect(animateShield ? 1.2 : 1)
                        .opacity(animateShield ? 0.8 : 0.6)
                    
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.system(size: 36))
                        .foregroundStyle(
                            LinearGradient(
                                colors: permissionManager.allPermissionsGranted
                                    ? [Color.success, Color.success.opacity(0.8)]
                                    : [Color.accent, Color.accent.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .symbolEffect(.pulse, value: animateShield)
                }
                .frame(height: 50)
                .onAppear {
                    withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                        animateShield = true
                    }
                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) {
                        showCards = true
                    }
                    
                    // Start monitoring permissions for live updates
                    permissionManager.startMonitoringPermissions()
                }
                
                // Title and subtitle
                VStack(spacing: 6) {
                    Text(permissionManager.allPermissionsGranted 
                        ? "Permissions Granted!" 
                        : "Let's set up Promptlet's superpowers")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(permissionManager.allPermissionsGranted 
                        ? "Promptlet can now work its magic anywhere"
                        : "Two quick permissions to work in any app")
                        .font(.system(size: 13))
                        .foregroundColor(.secondaryText)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(height: 130)
            
            // Middle section - Permission cards - 140px
            HStack(spacing: 16) {
                ModernPermissionCard(
                    title: "Accessibility",
                    subtitle: "Insert text instantly",
                    description: "Lets Promptlet type directly at your cursor",
                    example: "Works in any text field",
                    icon: "cursorarrow.rays",
                    isGranted: permissionManager.hasAccessibilityPermission,
                    isChecking: checkingPermissions,
                    showCard: showCards,
                    delay: 0.3,
                    action: {
                        requestPermission {
                            _ = permissionManager.requestAccessibilityPermission()
                        }
                    }
                )
                
                ModernPermissionCard(
                    title: "Automation", 
                    subtitle: "Send keystrokes",
                    description: "Allows typing your prompts automatically",
                    example: "Works in every app",
                    icon: "keyboard",
                    isGranted: permissionManager.hasAppleEventsPermission,
                    isChecking: checkingPermissions,
                    showCard: showCards,
                    delay: 0.4,
                    action: {
                        requestPermission {
                            permissionManager.requestAppleEventsPermission()
                        }
                    }
                )
            }
            .frame(height: 150)
            .padding(.horizontal, 60)
            
            // Bottom section - Privacy note - 100px
            VStack(spacing: 16) {
                // Privacy reassurance
                HStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.green)
                    
                    Text("Your data never leaves your Mac")
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.green.opacity(0.1))
                )
                
                // Status or help text
                if permissionManager.allPermissionsGranted {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.success)
                        Text("All set! Click Continue to proceed")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.success)
                    }
                    .transition(.scale.combined(with: .opacity))
                } else {
                    Text("Grant both permissions to continue")
                        .font(.system(size: 11))
                        .foregroundColor(.tertiaryText)
                }
            }
            .frame(height: 120)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.3), value: permissionManager.allPermissionsGranted)
    }
    
    private func requestPermission(action: @escaping () -> Void) {
        checkingPermissions = true
        action()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            permissionManager.checkAllPermissions()
            checkingPermissions = false
        }
    }
}

// Modern permission card with animations
struct ModernPermissionCard: View {
    let title: String
    let subtitle: String
    let description: String
    let example: String
    let icon: String
    let isGranted: Bool
    let isChecking: Bool
    let showCard: Bool
    let delay: Double
    let action: () -> Void
    
    @State private var isHovered = false
    @State private var animateIcon = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Top section with icon and title
            HStack(spacing: 12) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: isGranted 
                                    ? [Color.success.opacity(0.15), Color.success.opacity(0.05)]
                                    : [Color.accent.opacity(0.15), Color.accent.opacity(0.05)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 40, height: 40)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(
                            LinearGradient(
                                colors: isGranted
                                    ? [Color.success, Color.success.opacity(0.8)]
                                    : [Color.accent, Color.accent.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .scaleEffect(animateIcon ? 1.1 : 1)
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true).delay(delay)) {
                        animateIcon = true
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primaryText)
                    
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondaryText)
                }
                
                Spacer()
            }
            
            Spacer()
                .frame(height: 12)
            
            // Description
            Text(description)
                .font(.system(size: 11))
                .foregroundColor(.secondaryText)
                .lineLimit(2)
            
            // Example
            HStack(spacing: 4) {
                Text("✨")
                    .font(.system(size: 10))
                Text(example)
                    .font(.system(size: 10))
                    .foregroundColor(.tertiaryText)
            }
            .padding(.top, 4)
            
            Spacer()
            
            // Action button
            Group {
                if isChecking {
                    HStack {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.7)
                        Spacer()
                    }
                } else if isGranted {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.success)
                        Text("Granted")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.success)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.success.opacity(0.1))
                    )
                } else {
                    Button(action: action) {
                        Text("Grant Access")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(
                                    colors: [Color.accent, Color.accent.opacity(0.9)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .buttonStyle(.plain)
                    .scaleEffect(isHovered ? 1.02 : 1)
                }
            }
            .frame(height: 28)
        }
        .padding(16)
        .frame(width: 230, height: 140)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.secondaryBackground.opacity(0.5))
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.ultraThinMaterial)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isGranted ? Color.success.opacity(0.3) : Color.divider.opacity(0.5),
                            lineWidth: isGranted ? 1.5 : 1
                        )
                )
                .shadow(
                    color: (isGranted ? Color.success : Color.black).opacity(0.1),
                    radius: isHovered ? 12 : 8,
                    y: 4
                )
        )
        .scaleEffect(showCard ? 1 : 0.9)
        .opacity(showCard ? 1 : 0)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering && !isGranted
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isGranted)
    }
}