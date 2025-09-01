//
//  OnboardingService.swift
//  Promptlet
//
//  Manages the first-time user experience and onboarding flow
//  
//  This service handles:
//  - Onboarding window creation and management
//  - First-time setup flow
//  - Test notification handling during onboarding
//  - Completion tracking and callbacks
//

import Cocoa
import SwiftUI

@MainActor
class OnboardingService: OnboardingServiceProtocol {
    private var onboardingWindow: OnboardingWindow?
    private let settings: AppSettings
    
    init(settings: AppSettings) {
        self.settings = settings
    }
    
    var isOnboardingNeeded: Bool {
        !settings.hasCompletedOnboarding
    }
    
    func showOnboarding(onComplete: @escaping () -> Void) {
        logInfo(.onboarding, "Showing onboarding - first launch detected")
        
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindow()
        }
        
        let onboardingView = ModernOnboardingView(
            settings: settings,
            onComplete: { [weak self] in
                self?.completeOnboarding(onComplete: onComplete)
            }
        )
        
        onboardingWindow?.showOnboarding(with: onboardingView)
    }
    
    private func completeOnboarding(onComplete: @escaping () -> Void) {
        logSuccess(.onboarding, "Onboarding completed")
        
        onboardingWindow?.close()
        onboardingWindow = nil
        
        onComplete()
    }
    
    func handleTestNotifications() {
        // Listen for test notifications from onboarding
        NotificationCenter.default.addObserver(
            forName: Notification.Name("ShowPaletteTest"),
            object: nil,
            queue: .main
        ) { _ in
            logDebug(.onboarding, "Test show palette notification received")
            NotificationCenter.default.post(name: Notification.Name("TestShowPalette"), object: nil)
        }
        
        NotificationCenter.default.addObserver(
            forName: Notification.Name("HidePaletteTest"),
            object: nil,
            queue: .main
        ) { _ in
            logDebug(.onboarding, "Test hide palette notification received")
            NotificationCenter.default.post(name: Notification.Name("TestHidePalette"), object: nil)
        }
    }
}