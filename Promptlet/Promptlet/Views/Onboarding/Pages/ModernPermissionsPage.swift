//
//  ModernPermissionsPage.swift
//  Promptlet
//
//  Permissions request - no scrolling, fixed layout
//

import SwiftUI

struct ModernPermissionsPage: View {
    @ObservedObject var permissionManager: PermissionManager
    @State private var checkingPermissions = false
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
                .frame(height: 50)
            
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
            
            Spacer()
                .frame(height: 24)
            
            // Title
            VStack(spacing: 8) {
                Text(permissionManager.allPermissionsGranted ? "Permissions Granted" : "Permissions Required")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primaryText)
                
                Text(permissionManager.allPermissionsGranted 
                    ? "Promptlet is ready to assist you"
                    : "Promptlet needs permissions to work properly")
                    .font(.system(size: 13))
                    .foregroundColor(.secondaryText)
            }
            
            Spacer()
                .frame(height: 40)
            
            // Permission cards - horizontal layout
            HStack(spacing: 16) {
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
            .padding(.horizontal, 60)
            
            Spacer()
                .frame(height: 40)
            
            // Success state
            if permissionManager.allPermissionsGranted {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.success)
                    Text("All set!")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.success)
                }
                .transition(.scale.combined(with: .opacity))
            } else {
                Text("You can change permissions in System Settings")
                    .font(.system(size: 11))
                    .foregroundColor(.tertiaryText)
            }
            
            Spacer()
        }
        .frame(width: 600, height: 390)
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
        VStack(spacing: 16) {
            // Icon
            ZStack {
                Circle()
                    .fill(isGranted ? Color.success.opacity(0.1) : Color.accent.opacity(0.1))
                    .frame(width: 44, height: 44)
                
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(isGranted ? .success : .accent)
            }
            
            // Text
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primaryText)
                
                Text(description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondaryText)
            }
            
            // Action/Status
            if isChecking {
                ProgressView()
                    .scaleEffect(0.7)
                    .frame(height: 28)
            } else if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.success)
                    .frame(height: 28)
            } else {
                Button("Grant") {
                    action()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .frame(width: 220, height: 160)
        .padding(20)
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