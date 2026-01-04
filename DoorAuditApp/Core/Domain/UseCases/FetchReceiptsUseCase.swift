//
//  FetchReceiptsUseCase.swift
//  L1 Demo
//
//  Use Case for fetching receipts
//  Centralizes all receipt fetching logic
//  Created: December 2025
//

import Foundation

/// Fetches receipts from repository
protocol FetchReceiptsUseCase {
    func fetchAll() async throws -> [Receipt]
    func fetch(id: UUID) async throws -> Receipt?
    func fetchTodaysReceipts() async throws -> [Receipt]
    func fetchThisWeeksReceipts() async throws -> [Receipt]
    func fetchThisMonthsReceipts() async throws -> [Receipt]
    func fetchReceipts(for date: Date) async throws -> [Receipt]
    func fetchReceipts(from startDate: Date, to endDate: Date) async throws -> [Receipt]
    func searchReceipts(query: String) async throws -> [Receipt]
    func count() async throws -> Int
    func count(for date: Date) async throws -> Int
}

final class DefaultFetchReceiptsUseCase: FetchReceiptsUseCase {
    
    // MARK: - Dependencies
    
    private let receiptRepository: ReceiptRepository
    
    // MARK: - Initialization
    
    init(receiptRepository: ReceiptRepository) {
        self.receiptRepository = receiptRepository
    }
    
    // MARK: - Fetch Methods
    
    func fetchAll() async throws -> [Receipt] {
        Logger.shared.info("Fetching all receipts...")
        let receipts = try await receiptRepository.fetchAll()
        Logger.shared.info("Fetched \(receipts.count) receipts")
        return receipts
    }
    
    func fetch(id: UUID) async throws -> Receipt? {
        Logger.shared.debug("Fetching receipt: \(id)")
        return try await receiptRepository.fetch(id: id)
    }
    
    func fetchTodaysReceipts() async throws -> [Receipt] {
        Logger.shared.info("Fetching today's receipts...")
        let receipts = try await receiptRepository.fetchTodaysReceipts()
        Logger.shared.info("Found \(receipts.count) receipts for today")
        return receipts
    }
    
    func fetchThisWeeksReceipts() async throws -> [Receipt] {
        Logger.shared.info("Fetching this week's receipts...")
        let receipts = try await receiptRepository.fetchThisWeeksReceipts()
        Logger.shared.info("Found \(receipts.count) receipts this week")
        return receipts
    }
    
    func fetchThisMonthsReceipts() async throws -> [Receipt] {
        Logger.shared.info("Fetching this month's receipts...")
        let receipts = try await receiptRepository.fetchThisMonthsReceipts()
        Logger.shared.info("Found \(receipts.count) receipts this month")
        return receipts
    }
    
    func fetchReceipts(for date: Date) async throws -> [Receipt] {
        Logger.shared.info("Fetching receipts for \(date.displayString)...")
        let receipts = try await receiptRepository.fetchReceipts(for: date)
        Logger.shared.info("Found \(receipts.count) receipts for \(date.displayString)")
        return receipts
    }
    
    func fetchReceipts(from startDate: Date, to endDate: Date) async throws -> [Receipt] {
        Logger.shared.info("Fetching receipts from \(startDate.displayString) to \(endDate.displayString)...")
        let receipts = try await receiptRepository.fetchReceipts(from: startDate, to: endDate)
        Logger.shared.info("Found \(receipts.count) receipts in date range")
        return receipts
    }
    
    func searchReceipts(query: String) async throws -> [Receipt] {
        guard !query.isEmpty else {
            return try await fetchAll()
        }
        
        Logger.shared.info("Searching receipts for '\(query)'...")
        let receipts = try await receiptRepository.searchReceipts(query: query)
        Logger.shared.info("Found \(receipts.count) receipts matching '\(query)'")
        return receipts
    }
    
    func count() async throws -> Int {
        try await receiptRepository.count()
    }
    
    func count(for date: Date) async throws -> Int {
        try await receiptRepository.count(for: date)
    }
}
