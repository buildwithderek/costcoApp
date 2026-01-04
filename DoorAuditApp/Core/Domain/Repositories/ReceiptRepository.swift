//
//  ReceiptRepository.swift
//  L1 Demo
//
//  Protocol for receipt persistence
//  Abstracts away SwiftData - can swap to CoreData/REST/Firebase easily
//  Created: December 2025
//

import Foundation

/// Protocol defining receipt persistence operations
/// Implementation can be SwiftData, CoreData, REST API, etc.
protocol ReceiptRepository {
    
    // MARK: - Create
    
    /// Save a new receipt or update existing
    func save(_ receipt: Receipt) async throws
    
    /// Save multiple receipts
    func saveAll(_ receipts: [Receipt]) async throws
    
    // MARK: - Read
    
    /// Fetch a receipt by ID
    func fetch(id: UUID) async throws -> Receipt?
    
    /// Fetch all receipts
    func fetchAll() async throws -> [Receipt]
    
    /// Fetch receipts for a specific date
    func fetchReceipts(for date: Date) async throws -> [Receipt]
    
    /// Fetch receipts within a date range
    func fetchReceipts(from startDate: Date, to endDate: Date) async throws -> [Receipt]
    
    /// Fetch receipts matching a predicate
    func fetchReceipts(matching predicate: @escaping (Receipt) -> Bool) async throws -> [Receipt]
    
    /// Search receipts by text (barcode, transaction number, etc.)
    func searchReceipts(query: String) async throws -> [Receipt]
    
    // MARK: - Update
    
    /// Update an existing receipt
    func update(_ receipt: Receipt) async throws
    
    // MARK: - Delete
    
    /// Delete a receipt by ID
    func delete(id: UUID) async throws
    
    /// Delete a receipt
    func delete(_ receipt: Receipt) async throws
    
    /// Delete multiple receipts
    func deleteAll(_ receipts: [Receipt]) async throws
    
    /// Delete all receipts (use with caution!)
    func deleteAll() async throws
    
    // MARK: - Count
    
    /// Get total count of receipts
    func count() async throws -> Int
    
    /// Get count of receipts for a specific date
    func count(for date: Date) async throws -> Int
}

// MARK: - Default Implementations

extension ReceiptRepository {
    /// Fetch today's receipts
    func fetchTodaysReceipts() async throws -> [Receipt] {
        try await fetchReceipts(for: Date())
    }
    
    /// Fetch this week's receipts
    func fetchThisWeeksReceipts() async throws -> [Receipt] {
        let calendar = Calendar.current
        let now = Date()
        guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }
        return try await fetchReceipts(from: weekStart, to: weekEnd)
    }
    
    /// Fetch this month's receipts
    func fetchThisMonthsReceipts() async throws -> [Receipt] {
        let calendar = Calendar.current
        let now = Date()
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: now)),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return []
        }
        return try await fetchReceipts(from: monthStart, to: monthEnd)
    }
    
    /// Check if a receipt exists
    func exists(id: UUID) async throws -> Bool {
        try await fetch(id: id) != nil
    }
    
    /// Delete all implementation (calls deleteAll with array)
    func deleteAll() async throws {
        let receipts = try await fetchAll()
        try await deleteAll(receipts)
    }
}

// MARK: - Repository Errors

enum RepositoryError: LocalizedError {
    case notFound
    case saveFailed(Error)
    case fetchFailed(Error)
    case deleteFailed(Error)
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .notFound:
            return "Receipt not found"
        case .saveFailed(let error):
            return "Failed to save receipt: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch receipts: \(error.localizedDescription)"
        case .deleteFailed(let error):
            return "Failed to delete receipt: \(error.localizedDescription)"
        case .invalidData:
            return "Invalid receipt data"
        }
    }
}
