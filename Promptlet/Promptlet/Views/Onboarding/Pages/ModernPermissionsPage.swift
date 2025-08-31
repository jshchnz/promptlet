//
//  ModernPermissionsPage.swift
//  Promptlet
//
//  Permissions request - pixel-perfect spacing
//

import SwiftUI

struct ModernPermissionsPage: View {
    @ObservedObject var permissionManager: PermissionManager
    @State private var checkingPermissions = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Top spacing - 20px
            Spacer()
                .frame(height: 20)
            
            // Icon - 60x60
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(
                    LinearGradient(
                        colors: permissionManager.allPermissionsGranted
                            ? [Color.success, Color.success.opacity(0.8)]
                            : [Color.accent, Color.accent.opacity(0.8)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 60, height: 60)
            
            // Spacing - 20px
            Spacer()
                .frame(height: 20)
            
            // Title - ~45px
            VStack(spacing: 8) {
                Text(permissionManager.allPermissionsGranted ? "Permissions Granted" : "Permissions Required")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text(permissionManager.allPermissionsGranted 
                    ? "Promptlet is ready to assist you"
                    : "Promptlet needs permissions to work properly")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
                    .multilineTextAlignment(.center)
            }
            
            // Spacing - 25px
            Spacer()
                .frame(height: 25)
            
            // Permission cards - ~100px (cards are 140px tall with padding)
            HStack(spacing: 20) {
                PermissionCard(
                    title: "Accessibility",
                    description: "Insert text at cursor",
                    icon: "hand.tap.fill",
                    isGranted: permissionManager.hasAccessibilityPermission,
                    isChecking: checkingPermissions,
                    action: {
                        requestPermission {
                            _ = permissionManager.requestAccessibilityPermission()
                        }
                    }
                )
                
                PermissionCard(
                    title: "Apple Events",
                    description: "Send keystrokes",
                    icon: "paperplane.fill",
                    isGranted: permissionManager.hasAppleEventsPermission,
                    isChecking: checkingPermissions,
                    action: {
                        requestPermission {
                            permissionManager.requestAppleEventsPermission()
                        }
                    }
                )
            }
            .frame(height: 100)
            
            // Spacing - 20px
            Spacer()
                .frame(height: 20)
            
            // Footer - ~15px
            if permissionManager.allPermissionsGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.success)
                    Text("All set!")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.success)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("You can change permissions in System Settings")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            
            // Bottom spacing - 15px
            Spacer()
                .frame(height: 15)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeInOut(duration: 0.2), value: permissionManager.allPermissionsGranted)
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

// Compact permission card
struct PermissionCard: View {
    let title: String
    let description: String
    let icon: String
    let isGranted: Bool
    let isChecking: Bool
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.success.opacity(0.1) : Color.accent.opacity(0.1))
                    .frame(width: 36, height: 36)
                
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(isGranted ? .success : .accent)
            }
            
            // Text
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primaryText)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
            
            // Action/Status
            Group {
                if isChecking {
                    ProgressView()
                        .scaleEffect(0.7)
                } else if isGranted {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.success)
                } else {
                    Button("Grant") {
                        action()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            .frame(height: 24)
        }
        .frame(width: 180)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            isGranted ? Color.success.opacity(0.3) : Color.divider,
                            lineWidth: isGranted ? 2 : 1
                        )
                )
        )
        .animation(.easeInOut(duration: 0.2), value: isGranted)
    }
}