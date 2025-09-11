//
//  SparkleUpdaterService.swift
//  Promptlet
//
//  Manages automatic updates using Sparkle framework
//

import Foundation
import Combine

// Conditionally import Sparkle
#if canImport(Sparkle)
import Sparkle
#endif

@MainActor
class SparkleUpdaterService: NSObject, ObservableObject {
    static let shared = SparkleUpdaterService()
    
    @Published var isCheckingForUpdates = false
    @Published var updateCheckResult: UpdateCheckResult?
    @Published var lastCheckDate: Date?
    
    #if canImport(Sparkle)
    private var updaterController: SPUStandardUpdaterController?
    #endif
    private var cancellables = Set<AnyCancellable>()
    private var sparkleAvailable = false
    
    private override init() {
        super.init()
        setupUpdater()
    }
    
    // MARK: - Updater Setup
    
    private func setupUpdater() {
        #if canImport(Sparkle)
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: self,
            userDriverDelegate: nil
        )
        sparkleAvailable = true
        logInfo(.app, "Sparkle updater initialized successfully")
        #else
        logWarning(.app, "Sparkle framework not available - updates disabled")
        sparkleAvailable = false
        #endif
    }
    
    // MARK: - Update Checking
    
    func checkForUpdates() {
        guard sparkleAvailable else {
            logError(.app, "Sparkle framework not available")
            updateCheckResult = .error("Sparkle framework not linked. Please add Sparkle via Xcode Package Manager.")
            return
        }
        
        #if canImport(Sparkle)
        guard let updaterController = updaterController else {
            logError(.app, "Sparkle updater not initialized")
            updateCheckResult = .error("Update service not available")
            return
        }
        
        guard !isCheckingForUpdates else {
            logWarning(.app, "Update check already in progress")
            return
        }
        
        logInfo(.app, "Starting manual update check")
        isCheckingForUpdates = true
        updateCheckResult = nil
        
        updaterController.checkForUpdates(nil)
        #endif
    }
    
    func checkForUpdatesInBackground() {
        guard sparkleAvailable else { return }
        
        #if canImport(Sparkle)
        guard let updaterController = updaterController else { return }
        
        logDebug(.app, "Checking for updates in background")
        // SPUStandardUpdaterController handles background checks automatically
        lastCheckDate = Date()
        #endif
    }
    
    
    // MARK: - Configuration
    
    func setAutomaticUpdatesEnabled(_ enabled: Bool) {
        guard sparkleAvailable else { return }
        
        #if canImport(Sparkle)
        updaterController?.updater.automaticallyChecksForUpdates = enabled
        logInfo(.app, "Automatic updates \(enabled ? "enabled" : "disabled")")
        #endif
    }
    
    func getAutomaticUpdatesEnabled() -> Bool {
        guard sparkleAvailable else { return false }
        
        #if canImport(Sparkle)
        return updaterController?.updater.automaticallyChecksForUpdates ?? false
        #else
        return false
        #endif
    }
    
    // MARK: - State Queries
    
    func getCurrentVersion() -> String {
        return Bundle.main.appVersion ?? "Unknown"
    }
    
    func getBuildNumber() -> String {
        return Bundle.main.buildNumber ?? "Unknown"
    }
    
    func getLastCheckDateString() -> String {
        guard let lastCheck = lastCheckDate else {
            return "Never"
        }
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: lastCheck, relativeTo: Date())
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        logInfo(.app, "SparkleUpdaterService cleanup starting")
        cancellables.removeAll()
        #if canImport(Sparkle)
        updaterController = nil
        #endif
        logInfo(.app, "SparkleUpdaterService cleanup completed")
    }
}

// MARK: - Supporting Types

enum UpdateCheckResult {
    case noUpdatesAvailable
    #if canImport(Sparkle)
    case updateAvailable(SUAppcastItem)
    #else
    case updateAvailable(String)
    #endif
    case error(String)
    
    var localizedDescription: String {
        switch self {
        case .noUpdatesAvailable:
            return "You're running the latest version"
        case .updateAvailable(let item):
            #if canImport(Sparkle)
            let version = item.displayVersionString
            return "Update available: \(version)"
            #else
            return "Update available: \(item)"
            #endif
        case .error(let message):
            return "Check failed: \(message)"
        }
    }
    
    var isError: Bool {
        if case .error = self { return true }
        return false
    }
    
    var hasUpdate: Bool {
        if case .updateAvailable = self { return true }
        return false
    }
    
    #if canImport(Sparkle)
    var appcastItem: SUAppcastItem? {
        if case .updateAvailable(let item) = self { return item }
        return nil
    }
    #endif
}

// MARK: - SPUUpdaterDelegate

#if canImport(Sparkle)
extension SparkleUpdaterService: SPUUpdaterDelegate {
    nonisolated func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        Task { @MainActor in
            isCheckingForUpdates = false
            updateCheckResult = .updateAvailable(item)
            lastCheckDate = Date()
            
            logInfo(.app, "Update available: \(item.displayVersionString)")
        }
    }
    
    nonisolated func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        Task { @MainActor in
            isCheckingForUpdates = false
            updateCheckResult = .noUpdatesAvailable
            lastCheckDate = Date()
            
            logInfo(.app, "No updates available")
        }
    }
    
    nonisolated func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        Task { @MainActor in
            isCheckingForUpdates = false
            lastCheckDate = Date()
            
            if let error = error {
                updateCheckResult = .error(error.localizedDescription)
                logError(.app, "Update check failed: \(error)")
            }
        }
    }
}

// MARK: - Update Installation

extension SparkleUpdaterService {
    func installUpdate(for item: SUAppcastItem) {
        guard sparkleAvailable, let updaterController = updaterController else {
            logError(.app, "Sparkle updater not available")
            return
        }
        
        logInfo(.app, "Installing update")
        
        // Trigger update check which will show the update if available
        updaterController.checkForUpdates(nil)
    }
}
#endif

// MARK: - Bundle Extensions

extension Bundle {
    var appVersion: String? {
        return object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
    }
    
    var buildNumber: String? {
        return object(forInfoDictionaryKey: "CFBundleVersion") as? String
    }
}