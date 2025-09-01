//
//  LogService.swift
//  Promptlet
//
//  Centralized logging service with filtering and performance tracking
//

import Foundation

enum LogLevel: String, CaseIterable {
    case info = "INFO"
    case warning = "WARN"
    case error = "ERROR"
    case debug = "DEBUG"
    case success = "SUCCESS"
    
    var emoji: String {
        switch self {
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .debug: return "🔍"
        case .success: return "✅"
        }
    }
}

enum LogCategory: String, CaseIterable {
    case app = "App"
    case ui = "UI"
    case keyboard = "Keyboard"
    case window = "Window"
    case prompt = "Prompt"
    case settings = "Settings"
    case permission = "Permission"
    case performance = "Performance"
    case textInsertion = "TextInsertion"
    case onboarding = "Onboarding"
}

struct LogEntry {
    let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: String
    let message: String
    let file: String?
    let function: String?
    let line: Int?
    
    init(level: LogLevel, category: String, message: String, file: String? = nil, function: String? = nil, line: Int? = nil) {
        self.timestamp = Date()
        self.level = level
        self.category = category
        self.message = message
        self.file = file
        self.function = function
        self.line = line
    }
    
    var formattedString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        let timeStr = formatter.string(from: timestamp)
        let locationStr = file != nil ? " (\(file!):\(line ?? 0))" : ""
        return "[\(timeStr)] \(level.emoji) [\(category)] \(message)\(locationStr)"
    }
    
    var consoleString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return "[\(formatter.string(from: timestamp))] \(level.rawValue): [\(category)] \(message)"
    }
}

@MainActor
class LogService: ObservableObject {
    static let shared = LogService()
    
    @Published var logs: [LogEntry] = []
    @Published var isEnabled = true
    private let maxLogs = 1000
    private var performanceTimers: [String: Date] = [:]
    
    var filteredCategories: Set<String> = []
    var filteredLevels: Set<LogLevel> = []
    
    private init() {
        addLog(level: .info, category: LogCategory.app.rawValue, message: "Logging service initialized")
    }
    
    func addLog(level: LogLevel, category: String, message: String, file: String = #file, function: String = #function, line: Int = #line) {
        guard isEnabled else { return }
        
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        let entry = LogEntry(
            level: level,
            category: category,
            message: message,
            file: fileName,
            function: function,
            line: line
        )
        
        logs.append(entry)
        
        if logs.count > maxLogs {
            logs.removeFirst(logs.count - maxLogs)
        }
        
        #if DEBUG
        print(entry.consoleString)
        #endif
    }
    
    func startPerformanceTimer(_ identifier: String) {
        performanceTimers[identifier] = Date()
    }
    
    func endPerformanceTimer(_ identifier: String, message: String? = nil) {
        guard let startTime = performanceTimers[identifier] else { return }
        let duration = Date().timeIntervalSince(startTime)
        let msg = message ?? "Operation completed"
        addLog(level: .debug, category: LogCategory.performance.rawValue, message: "\(msg): \(String(format: "%.2fms", duration * 1000))")
        performanceTimers.removeValue(forKey: identifier)
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
    func info(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        addLog(level: .info, category: category, message: message, file: file, function: function, line: line)
    }
    
    func warning(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        addLog(level: .warning, category: category, message: message, file: file, function: function, line: line)
    }
    
    func error(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        addLog(level: .error, category: category, message: message, file: file, function: function, line: line)
    }
    
    func debug(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        addLog(level: .debug, category: category, message: message, file: file, function: function, line: line)
    }
    
    func success(_ category: String, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
        addLog(level: .success, category: category, message: message, file: file, function: function, line: line)
    }
}

// MARK: - Global logging functions for convenience
func logInfo(_ category: LogCategory, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LogService.shared.info(category.rawValue, message, file: file, function: function, line: line)
    }
}

func logWarning(_ category: LogCategory, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LogService.shared.warning(category.rawValue, message, file: file, function: function, line: line)
    }
}

func logError(_ category: LogCategory, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LogService.shared.error(category.rawValue, message, file: file, function: function, line: line)
    }
}

func logDebug(_ category: LogCategory, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LogService.shared.debug(category.rawValue, message, file: file, function: function, line: line)
    }
}

func logSuccess(_ category: LogCategory, _ message: String, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        LogService.shared.success(category.rawValue, message, file: file, function: function, line: line)
    }
}

// MARK: - Performance Logging
func logPerformanceStart(_ identifier: String) {
    Task { @MainActor in
        LogService.shared.startPerformanceTimer(identifier)
    }
}

func logPerformanceEnd(_ identifier: String, _ message: String? = nil) {
    Task { @MainActor in
        LogService.shared.endPerformanceTimer(identifier, message: message)
    }
}