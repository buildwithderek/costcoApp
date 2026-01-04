//
//  Logger.swift
//  L1 Demo
//
//  Centralized logging system
//  Created: December 2025
//

import Foundation
import os.log

/// Centralized logging for the entire app
/// Usage: Logger.shared.info("Message")
final class Logger {
    
    // MARK: - Singleton
    
    static let shared = Logger()
    
    // MARK: - Properties
    
    private let logger: os.Logger
    
    // MARK: - Initialization
    
    private init() {
        let subsystem = Bundle.main.bundleIdentifier ?? "com.costco.l1demo"
        self.logger = os.Logger(subsystem: subsystem, category: "app")
    }
    
    // MARK: - Logging Methods
    
    /// Log informational message
    func info(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        #if DEBUG
        let context = formatContext(file: file, line: line, function: function)
        logger.info("ℹ️ [\(context)] \(message)")
        #else
        logger.info("\(message)")
        #endif
    }
    
    /// Log error message
    func error(_ message: String, error: Error? = nil, file: String = #file, line: Int = #line, function: String = #function) {
        let context = formatContext(file: file, line: line, function: function)
        
        if let error = error {
            logger.error("❌ [\(context)] \(message) - Error: \(error.localizedDescription)")
        } else {
            logger.error("❌ [\(context)] \(message)")
        }
    }
    
    /// Log warning message
    func warning(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        #if DEBUG
        let context = formatContext(file: file, line: line, function: function)
        logger.warning("⚠️ [\(context)] \(message)")
        #else
        logger.warning("\(message)")
        #endif
    }
    
    /// Log debug message (only in DEBUG builds)
    func debug(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        #if DEBUG
        let context = formatContext(file: file, line: line, function: function)
        logger.debug("🔍 [\(context)] \(message)")
        #endif
    }
    
    /// Log success message
    func success(_ message: String, file: String = #file, line: Int = #line, function: String = #function) {
        #if DEBUG
        let context = formatContext(file: file, line: line, function: function)
        logger.info("✅ [\(context)] \(message)")
        #else
        logger.info("\(message)")
        #endif
    }
    
    // MARK: - Helper Methods
    
    private func formatContext(file: String, line: Int, function: String) -> String {
        let fileName = (file as NSString).lastPathComponent.replacingOccurrences(of: ".swift", with: "")
        return "\(fileName):\(line) \(function)"
    }
}

// MARK: - Convenience Extensions

extension Logger {
    /// Log start of async operation
    func startOperation(_ operation: String) {
        debug("▶️ Starting: \(operation)")
    }
    
    /// Log end of async operation
    func endOperation(_ operation: String, duration: TimeInterval? = nil) {
        if let duration = duration {
            debug("⏹️ Completed: \(operation) (took \(String(format: "%.2f", duration))s)")
        } else {
            debug("⏹️ Completed: \(operation)")
        }
    }
}
