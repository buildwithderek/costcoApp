//
//  AuditViewModel.swift
//  L1 Demo
//
//  ViewModel for QuickAuditView
//  Handles: Staff selection, issue entry, audit saving
//  Created: December 2025
//

import Foundation
import SwiftUI
import Observation

/// ViewModel for audit screen (QuickAuditView)
@Observable
final class AuditViewModel {
    
    // MARK: - State
    
    let receipt: Receipt
    var audit: AuditData?
    
    // Form fields
    var selectedStaffName = ""
    var auditorName = ""
    var itemCount = ""
    var notes = ""
    var issue1 = ""
    var issue2 = ""
    var issue3 = ""
    
    var isSaving = false
    var showSuccessMessage = false
    var error: Error?
    
    // MARK: - Dependencies
    
    private let auditRepository: AuditRepository
    private let saveAudit: SaveAuditUseCase
    
    // MARK: - Initialization
    
    init(
        receipt: Receipt,
        auditRepository: AuditRepository,
        saveAudit: SaveAuditUseCase
    ) {
        self.receipt = receipt
        self.auditRepository = auditRepository
        self.saveAudit = saveAudit
        
        // Load existing audit if it exists
        Task {
            await loadExistingAudit()
        }
    }
    
    // MARK: - Computed Properties
    
    var isValid: Bool {
        !selectedStaffName.isEmpty
    }
    
    var hasIssues: Bool {
        !issue1.isEmpty || !issue2.isEmpty || !issue3.isEmpty
    }
    
    var isComplete: Bool {
        !selectedStaffName.isEmpty
    }
    
    var auditStatus: AuditData.AuditStatus {
        if isComplete {
            return .completed
        } else {
            return .pending
        }
    }
    
    var itemCountValue: Int? {
        Int(itemCount)
    }
    
    // MARK: - Actions
    
    /// Load existing audit for this receipt
    @MainActor
    private func loadExistingAudit() async {
        do {
            if let existingAudit = try await auditRepository.fetchAudit(for: receipt.id) {
                self.audit = existingAudit
                populateFields(from: existingAudit)
                Logger.shared.info("Loaded existing audit: \(existingAudit.id)")
            }
        } catch {
            Logger.shared.error("Failed to load audit", error: error)
        }
    }
    
    /// Populate form fields from existing audit
    private func populateFields(from audit: AuditData) {
        selectedStaffName = audit.staffName
        auditorName = audit.auditorName ?? ""
        itemCount = audit.itemCount.map { String($0) } ?? ""
        notes = audit.notes ?? ""
        issue1 = audit.issue1 ?? ""
        issue2 = audit.issue2 ?? ""
        issue3 = audit.issue3 ?? ""
    }
    
    /// Save the audit
    @MainActor
    func save() async {
        guard isValid else {
            error = AuditError.invalidData
            return
        }
        
        isSaving = true
        error = nil
        
        do {
            // Create or update audit
            let auditData = AuditData(
                id: audit?.id ?? UUID(),
                receiptID: receipt.id,
                timestamp: Date(),
                staffName: selectedStaffName,
                auditorName: auditorName.isEmpty ? nil : auditorName,
                itemCount: itemCountValue,
                notes: notes.isEmpty ? nil : notes,
                issue1: issue1.isEmpty ? nil : issue1,
                issue2: issue2.isEmpty ? nil : issue2,
                issue3: issue3.isEmpty ? nil : issue3
            )
            
            try await saveAudit.execute(audit: auditData)
            
            self.audit = auditData
            showSuccessMessage = true
            
            Logger.shared.success("Audit saved: \(auditData.id)")
            
            // Hide success message after delay
            try? await Task.sleep(for: .seconds(AppConstants.Animation.successDuration))
            showSuccessMessage = false
            
        } catch {
            Logger.shared.error("Failed to save audit", error: error)
            self.error = error
        }
        
        isSaving = false
    }
    
    /// Quick save (without validation)
    @MainActor
    func quickSave() async {
        await save()
    }
    
    /// Clear a specific issue
    func clearIssue(_ issueNumber: Int) {
        switch issueNumber {
        case 1: issue1 = ""
        case 2: issue2 = ""
        case 3: issue3 = ""
        default: break
        }
    }
    
    /// Clear all issues
    func clearAllIssues() {
        issue1 = ""
        issue2 = ""
        issue3 = ""
    }
    
    /// Clear error
    func clearError() {
        error = nil
    }
    
    /// Reset form
    func reset() {
        selectedStaffName = ""
        auditorName = ""
        itemCount = ""
        notes = ""
        issue1 = ""
        issue2 = ""
        issue3 = ""
        error = nil
        showSuccessMessage = false
    }
}

// MARK: - Errors

enum AuditError: LocalizedError {
    case invalidData
    case missingStaff
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Please fill in all required fields"
        case .missingStaff:
            return "Staff name is required"
        case .saveFailed:
            return "Failed to save audit"
        }
    }
}

// MARK: - Preview

#if DEBUG
extension AuditViewModel {
    static var preview: AuditViewModel {
        let mockRepo = MockAuditRepository()
        let mockSave = MockSaveAuditUseCase()
        
        let vm = AuditViewModel(
            receipt: .sample,
            auditRepository: mockRepo,
            saveAudit: mockSave
        )
        
        // Populate with sample data
        vm.selectedStaffName = "John Doe"
        vm.itemCount = "12"
        
        return vm
    }
    
    static var previewWithIssues: AuditViewModel {
        let mockRepo = MockAuditRepository()
        let mockSave = MockSaveAuditUseCase()
        
        let vm = AuditViewModel(
            receipt: .sample,
            auditRepository: mockRepo,
            saveAudit: mockSave
        )
        
        vm.selectedStaffName = "John Doe"
        vm.itemCount = "8"
        vm.issue1 = "Missing item #123456"
        vm.issue2 = "Wrong quantity on bananas"
        
        return vm
    }
}

// Mock implementations
private class MockAuditRepository: AuditRepository {
    func fetchAudit(for receiptID: UUID) async throws -> AuditData? {
        nil
    }
    
    func save(_ audit: AuditData) async throws {
        // Mock save
    }
    
    // Other required methods...
    func fetch(id: UUID) async throws -> AuditData? { nil }
    func fetchAll() async throws -> [AuditData] { [] }
    func fetchAudits(for date: Date) async throws -> [AuditData] { [] }
    func fetchAudits(from startDate: Date, to endDate: Date) async throws -> [AuditData] { [] }
    func fetchAuditsWithIssues() async throws -> [AuditData] { [] }
    func fetchCompletedAudits() async throws -> [AuditData] { [] }
    func fetchPendingAudits() async throws -> [AuditData] { [] }
    func saveAll(_ audits: [AuditData]) async throws {}
    func update(_ audit: AuditData) async throws {}
    func delete(id: UUID) async throws {}
    func delete(_ audit: AuditData) async throws {}
    func deleteAudits(for receiptID: UUID) async throws {}
    func deleteAll() async throws {}
    func count() async throws -> Int { 0 }
    func countWithIssues() async throws -> Int { 0 }
    func countCompleted() async throws -> Int { 0 }
}

private class MockSaveAuditUseCase: SaveAuditUseCase {
    func execute(audit: AuditData) async throws {
        // Mock save
    }
}
#endif
