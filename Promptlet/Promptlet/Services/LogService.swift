//
//  LogService.swift
//  Promptlet
//
//  Simple logging service for debug purposes
//

import Foundation

enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"
    case success = "SUCCESS"
}

struct LogEntry {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    
    var formattedString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return "[\(formatter.string(from: timestamp))] \(level.rawValue): [\(category)] \(message)"
    }
}

@MainActor
class LogService: ObservableObject {
    static let shared = LogService()
    
    @Published var logs: [LogEntry] = []
    private let maxLogs = 1000 // Keep last 1000 log entries
    
    private init() {
        // Add initial startup log
        addLog(level: .info, category: "LogService", message: "Logging service initialized")
    }
    
    func addLog(level: LogLevel, category: String, message: String) {
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message
        )
        
        logs.append(entry)
        
        // Keep only the most recent logs
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        
        // Also print to console for development
        print(entry.formattedString)
    }
    
    func clearLogs() {
        logs.removeAll()
        addLog(level: .info, category: "LogService", message: "Logs cleared by user")
    }
    
    func getLogsAsString() -> String {
        return logs.map { $0.formattedString }.joined(separator: "\n")
    }
    
    func getLogsForLevel(_ level: LogLevel) -> [LogEntry] {
        return logs.filter { $0.level == level }
    }
    
    func getLogsForCategory(_ category: String) -> [LogEntry] {
        return logs.filter { $0.category == category }
    }
}

// MARK: - Convenience logging functions
extension LogService {
    func info(_ category: String, _ message: String) {
        addLog(level: .info, category: category, message: message)
    }
    
    func warning(_ category: String, _ message: String) {
        addLog(level: .warning, category: category, message: message)
    }
    
    func error(_ category: String, _ message: String) {
        addLog(level: .error, category: category, message: message)
    }
    
    func debug(_ category: String, _ message: String) {
        addLog(level: .debug, category: category, message: message)
    }
    
    func success(_ category: String, _ message: String) {
        addLog(level: .success, category: category, message: message)
    }
}

// MARK: - Global logging functions for convenience
func logInfo(_ category: String, _ message: String) {
    Task { @MainActor in
        LogService.shared.info(category, message)
    }
}

func logWarning(_ category: String, _ message: String) {
    Task { @MainActor in
        LogService.shared.warning(category, message)
    }
}

func logError(_ category: String, _ message: String) {
    Task { @MainActor in
        LogService.shared.error(category, message)
    }
}

func logDebug(_ category: String, _ message: String) {
    Task { @MainActor in
        LogService.shared.debug(category, message)
    }
}

func logSuccess(_ category: String, _ message: String) {
    Task { @MainActor in
        LogService.shared.success(category, message)
    }
}