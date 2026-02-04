//
//  ReceiptListViewModel.swift
//  L1 Demo
//
//  ViewModel for receipts list view
//  Handles: Loading, filtering, searching, deleting receipts
//  Created: December 2025
//

import Foundation
import SwiftUI
import Observation

/// ViewModel for ReceiptsListView
@Observable
final class ReceiptListViewModel {
    
    // MARK: - State
    
    var receipts: [Receipt] = []
    var filteredReceipts: [Receipt] = []
    var searchQuery = "" {
        didSet { filterReceipts() }
    }
    var selectedFilter: FilterOption = .all {
        didSet { Task { await loadReceipts() } }
    }
    var isLoading = false
    var error: Error?
    
    // Selection
    var selectedReceipts: Set<UUID> = []
    var isSelectionMode = false
    
    // MARK: - Filter Options
    
    enum FilterOption: String, CaseIterable {
        case all = "All"
        case today = "Today"
        case thisWeek = "This Week"
        case thisMonth = "This Month"
        
        var displayName: String { rawValue }
    }
    
    // MARK: - Dependencies
    
    private let fetchReceipts: FetchReceiptsUseCase
    private let deleteReceipt: DeleteReceiptUseCase

    
    // MARK: - Initialization
    
    init(
        fetchReceipts: FetchReceiptsUseCase,
        deleteReceipt: DeleteReceiptUseCase
    ) {
        self.fetchReceipts = fetchReceipts
        self.deleteReceipt = deleteReceipt

    }
    
    // MARK: - Computed Properties
    
    var displayReceipts: [Receipt] {
        searchQuery.isEmpty ? receipts : filteredReceipts
    }
    
    var hasSelectedReceipts: Bool {
        !selectedReceipts.isEmpty
    }
    
    var selectedCount: Int {
        selectedReceipts.count
    }
    
    // MARK: - Actions
    
    /// Load receipts based on current filter
    @MainActor
    func loadReceipts() async {
        isLoading = true
        error = nil
        
        do {
            switch selectedFilter {
            case .all:
                receipts = try await fetchReceipts.fetchAll()
            case .today:
                receipts = try await fetchReceipts.fetchTodaysReceipts()
            case .thisWeek:
                receipts = try await fetchReceipts.fetchThisWeeksReceipts()
            case .thisMonth:
                receipts = try await fetchReceipts.fetchThisMonthsReceipts()
            }
            
            Logger.shared.info("Loaded \(receipts.count) receipts (filter: \(selectedFilter.displayName))")
            
        } catch {
            Logger.shared.error("Failed to load receipts", error: error)
            self.error = error
        }
        
        isLoading = false
    }
    
    /// Search receipts
    private func filterReceipts() {
        guard !searchQuery.isEmpty else {
            filteredReceipts = []
            return
        }
        
        let query = searchQuery.lowercased()
        filteredReceipts = receipts.filter { receipt in
            // Search in barcode
            if let barcode = receipt.barcodeValue, barcode.lowercased().contains(query) {
                return true
            }
            
            // Search in transaction number
            if let transaction = receipt.transactionNumber, transaction.lowercased().contains(query) {
                return true
            }
            
            // Search in register number
            if let register = receipt.registerNumber, register.lowercased().contains(query) {
                return true
            }
            
            // Search in raw text
            if receipt.rawText.lowercased().contains(query) {
                return true
            }
            
            return false
        }
        
        Logger.shared.debug("Search '\(query)' found \(filteredReceipts.count) results")
    }
    
    /// Delete a single receipt
    @MainActor
    func delete(_ receipt: Receipt) async {
        do {
            try await deleteReceipt.execute(receiptID: receipt.id)
            
            // Remove from local array
            receipts.removeAll { $0.id == receipt.id }
            filteredReceipts.removeAll { $0.id == receipt.id }
            
            Logger.shared.info("Deleted receipt: \(receipt.id)")
            
        } catch {
            Logger.shared.error("Failed to delete receipt", error: error)
            self.error = error
        }
    }
    
    /// Delete selected receipts
    @MainActor
    func deleteSelected() async {
        let receiptsToDelete = receipts.filter { selectedReceipts.contains($0.id) }
        
        for receipt in receiptsToDelete {
            await delete(receipt)
        }
        
        // Clear selection
        selectedReceipts.removeAll()
        isSelectionMode = false
    }
    
    /// Toggle receipt selection
    func toggleSelection(_ receipt: Receipt) {
        if selectedReceipts.contains(receipt.id) {
            selectedReceipts.remove(receipt.id)
        } else {
            selectedReceipts.insert(receipt.id)
        }
    }
    
    /// Select all receipts
    func selectAll() {
        selectedReceipts = Set(displayReceipts.map { $0.id })
    }
    
    /// Deselect all receipts
    func deselectAll() {
        selectedReceipts.removeAll()
    }
    
    /// Enter selection mode
    func enterSelectionMode() {
        isSelectionMode = true
    }
    
    /// Exit selection mode
    func exitSelectionMode() {
        isSelectionMode = false
        selectedReceipts.removeAll()
    }
    
    /// Refresh receipts
    @MainActor
    func refresh() async {
        await loadReceipts()
    }
    
    /// Clear error
    func clearError() {
        error = nil
    }
}

// MARK: - Preview

#if DEBUG
extension ReceiptListViewModel {
    static var preview: ReceiptListViewModel {
        let mockFetch = MockFetchReceiptsUseCaseForList()
        let mockDelete = MockDeleteReceiptUseCase()
        
        let vm = ReceiptListViewModel(
            fetchReceipts: mockFetch,
            deleteReceipt: mockDelete,
        )
        
        // Populate with sample data
        vm.receipts = [
            .sample,
            .sampleWithoutBarcode,
            .sampleIncomplete,
            Receipt(
                barcodeValue: "999888777666",
                storeName: "COSTCO",
                totalAmount: 89.99,
                rawText: "Another receipt",
                registerNumber: "5",
                transactionNumber: "0234"
            )
        ]
        
        return vm
    }
}

// Mock implementations
private class MockFetchReceiptsUseCaseForList: FetchReceiptsUseCase {
    func fetchAll() async throws -> [Receipt] {
        [.sample, .sample]
    }
    
    func fetch(id: UUID) async throws -> Receipt? { nil }
    
    func fetchTodaysReceipts() async throws -> [Receipt] {
        [.sample]
    }
    
    func fetchThisWeeksReceipts() async throws -> [Receipt] {
        [.sample, .sample]
    }
    
    func fetchThisMonthsReceipts() async throws -> [Receipt] {
        [.sample, .sample, .sample]
    }
    
    func fetchReceipts(for date: Date) async throws -> [Receipt] { [] }
    
    func fetchReceipts(from startDate: Date, to endDate: Date) async throws -> [Receipt] { [] }
    
    func searchReceipts(query: String) async throws -> [Receipt] { [] }
    
    func count() async throws -> Int {
        10
    }
    
    func count(for date: Date) async throws -> Int { 0 }
}

private class MockDeleteReceiptUseCase: DeleteReceiptUseCase {
    func execute(receiptID: UUID) async throws {
        // Mock deletion
    }
    
    func execute(receipt: Receipt) async throws {
        // Mock deletion
    }
    
    func deleteMultiple(receiptIDs: [UUID]) async throws {
        // Mock deletion
    }
}

#endif
