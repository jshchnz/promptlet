//
//  ModernOnboardingView.swift
//  Promptlet
//
//  Premium 3-step onboarding with Apple-quality design
//

import SwiftUI

struct ModernOnboardingView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissionManager = PermissionManager.shared
    @State private var currentStep = 0
    @Environment(\.dismiss) private var dismiss
    
    let onComplete: () -> Void
    
    // Always show 3 steps
    private let totalSteps = 3
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - 80px with more padding
            HStack(spacing: Spacing.md) {
                ProgressDots(currentPage: currentStep, totalPages: totalSteps)
                
                Spacer()
                
                if currentStep < totalSteps - 1 {
                    Button("Skip") {
                        completeOnboarding()
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.tertiaryText)
                    .font(Typography.caption())
                }
            }
            .padding(.horizontal, 70)
            .frame(height: 80)
            
            // Content area - 380px
            ZStack {
                switch currentStep {
                case 0:
                    WelcomeSetupPage(settings: settings)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .opacity
                        ))
                case 1:
                    ModernPermissionsPage(permissionManager: permissionManager)
                        .transition(.opacity)
                case 2:
                    ReadyPage(onTest: testShortcut)
                        .transition(.opacity)
                default:
                    EmptyView()
                }
            }
            .padding(50)
            .frame(width: 680, height: 380)
            .animation(.easeInOut(duration: 0.2), value: currentStep)
            
            // Footer - 80px with more padding
            HStack(spacing: Spacing.md) {
                if currentStep > 0 {
                    Button("Back") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep -= 1
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.primaryText)
                }
                
                Spacer()
                
                if currentStep == totalSteps - 1 {
                    Button("Get Started") {
                        completeOnboarding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .keyboardShortcut(.defaultAction)
                } else {
                    Button("Continue") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            currentStep += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(!canProceedToNext())
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.horizontal, 70)
            .frame(height: 80)
        }
        .frame(width: 680, height: 540)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(NSColor.windowBackgroundColor))
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onKeyPress(.leftArrow) {
            if currentStep > 0 {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentStep -= 1
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.rightArrow) {
            if currentStep < totalSteps - 1 && canProceedToNext() {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentStep += 1
                }
                return .handled
            }
            return .ignored
        }
        .onKeyPress(.return) {
            if currentStep == totalSteps - 1 {
                completeOnboarding()
            } else if canProceedToNext() {
                withAnimation(.easeInOut(duration: 0.2)) {
                    currentStep += 1
                }
            }
            return .handled
        }
    }
    
    private func canProceedToNext() -> Bool {
        switch currentStep {
        case 0:
            return settings.getShortcut(for: .showPalette) != nil
        case 1:
            return permissionManager.allPermissionsGranted
        default:
            return true
        }
    }
    
    private func testShortcut() {
        // Trigger the palette to show briefly
        NotificationCenter.default.post(name: Notification.Name("ShowPaletteTest"), object: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            NotificationCenter.default.post(name: Notification.Name("HidePaletteTest"), object: nil)
        }
    }
    
    private func completeOnboarding() {
        permissionManager.stopMonitoring()
        settings.hasCompletedOnboarding = true
        settings.onboardingVersion = 2
        onComplete()
        dismiss()
    }
}