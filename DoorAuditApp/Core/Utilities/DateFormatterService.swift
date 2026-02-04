//
//  DateFormatterService.swift
//  L1 Demo
//
//  Centralized date formatting service
//  Eliminates duplicate DateFormatter instances across the app
//  Created: December 2025
//

import Foundation

/// Thread-safe date formatting service
/// Reuses formatters for performance
final class DateFormatterService {
    
    // MARK: - Singleton
    
    static let shared = DateFormatterService()
    
    // MARK: - Properties
    
    private let queue = DispatchQueue(label: "com.l1demo.dateformatter", attributes: .concurrent)
    private var formatters: [String: DateFormatter] = [:]
    
    // MARK: - Initialization
    
    private init() {
        // Pre-create commonly used formatters
        _ = getFormatter(for: .display)
        _ = getFormatter(for: .receipt)
        _ = getFormatter(for: .short)
    }
    
    // MARK: - Formatter Types
    
    enum FormatterType {
        case display           // "Jan 15, 2025"
        case displayWithTime   // "Jan 15, 2025 at 2:30 PM"
        case short            // "1/15/25"
        case receipt          // "01/15/2025"
        case receiptWithTime  // "01/15/2025 14:30:45"
        case timeOnly         // "2:30 PM"
        case iso8601          // "2025-01-15T14:30:45Z"
        case filename         // "2025-01-15_1430"
        case custom(String)   // Custom format string
        
        var formatString: String {
            switch self {
            case .display: return AppConstants.DateFormat.display
            case .displayWithTime: return AppConstants.DateFormat.displayWithTime
            case .short: return AppConstants.DateFormat.short
            case .receipt: return AppConstants.DateFormat.receipt
            case .receiptWithTime: return AppConstants.DateFormat.receiptWithTime
            case .timeOnly: return AppConstants.DateFormat.timeOnly
            case .iso8601: return AppConstants.DateFormat.iso8601
            case .filename: return AppConstants.Export.filenameDateFormat
            case .custom(let format): return format
            }
        }
    }
    
    // MARK: - Public Methods
    
    /// Format a date using the specified formatter type
    func string(from date: Date, type: FormatterType = .display) -> String {
        let formatter = getFormatter(for: type)
        return formatter.string(from: date)
    }
    
    /// Parse a string into a date using the specified formatter type
    func date(from string: String, type: FormatterType = .display) -> Date? {
        let formatter = getFormatter(for: type)
        return formatter.date(from: string)
    }
    
    // MARK: - Private Methods
    
    private func getFormatter(for type: FormatterType) -> DateFormatter {
        let key = type.formatString
        
        return queue.sync {
            if let existing = formatters[key] {
                return existing
            }
            
            let formatter = DateFormatter()
            formatter.dateFormat = type.formatString
            formatter.locale = Locale.current
            formatter.timeZone = TimeZone.current
            
            formatters[key] = formatter
            return formatter
        }
    }
}

// MARK: - Convenience Extensions

extension Date {
    /// Format this date for display: "Jan 15, 2025"
    var displayString: String {
        DateFormatterService.shared.string(from: self, type: .display)
    }
    
    /// Format this date for display with time: "Jan 15, 2025 at 2:30 PM"
    var displayStringWithTime: String {
        DateFormatterService.shared.string(from: self, type: .displayWithTime)
    }
    
    /// Format this date for receipts: "01/15/2025"
    var receiptString: String {
        DateFormatterService.shared.string(from: self, type: .receipt)
    }
    
    /// Format this date for receipts with time: "01/15/2025 14:30:45"
    var receiptStringWithTime: String {
        DateFormatterService.shared.string(from: self, type: .receiptWithTime)
    }
    
    /// Format this date for filenames: "2025-01-15_1430"
    var filenameString: String {
        DateFormatterService.shared.string(from: self, type: .filename)
    }
    
    /// Check if date is today
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    /// Check if date is yesterday
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    /// Check if date is in current week
    var isThisWeek: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .weekOfYear)
    }
    
    /// Check if date is in current month
    var isThisMonth: Bool {
        Calendar.current.isDate(self, equalTo: Date(), toGranularity: .month)
    }
    
    /// Start of day (00:00:00)
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    /// End of day (23:59:59)
    var endOfDay: Date {
        var components = DateComponents()
        components.day = 1
        components.second = -1
        return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
    }
    
    /// Relative string: "Today", "Yesterday", or formatted date
    var relativeString: String {
        if isToday {
            return "Today"
        } else if isYesterday {
            return "Yesterday"
        } else if isThisWeek {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE" // Day name
            return formatter.string(from: self)
        } else {
            return displayString
        }
    }
}

// MARK: - String Extensions

extension String {
    /// Parse this string as a date using the specified format
    func toDate(format: DateFormatterService.FormatterType = .display) -> Date? {
        DateFormatterService.shared.date(from: self, type: format)
    }
}
