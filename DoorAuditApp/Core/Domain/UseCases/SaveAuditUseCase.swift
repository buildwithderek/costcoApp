//
//  SaveAuditUseCase.swift
//  L1 Demo
//
//  Use Case for saving audit data
//  Handles validation and persistence of audits
//  Created: December 2025
//

import Foundation

/// Saves audit data with validation
protocol SaveAuditUseCase {
    func execute(audit: AuditData) async throws
}

final class DefaultSaveAuditUseCase: SaveAuditUseCase {
    
    // MARK: - Dependencies
    
    private let auditRepository: AuditRepository
    
    // MARK: - Initialization
    
    init(auditRepository: AuditRepository) {
        self.auditRepository = auditRepository
    }
    
    // MARK: - Execute
    
    func execute(audit: AuditData) async throws {
        Logger.shared.info("Saving audit for receipt: \(audit.receiptID)")
        
        // Validate audit data
        do {
            try audit.validate()
        } catch {
            Logger.shared.error("Audit validation failed", error: error)
            throw SaveAuditError.validationFailed(error)
        }
        
        // Check if audit already exists
        let existingAudit = try? await auditRepository.fetchAudit(for: audit.receiptID)
        
        if let existing = existingAudit {
            // Update existing audit
            Logger.shared.info("Updating existing audit: \(existing.id)")
            
            // Create updated audit with same ID
            let updatedAudit = AuditData(
                id: existing.id,  // Keep same ID
                receiptID: audit.receiptID,
                timestamp: Date(),  // Update timestamp
                staffName: audit.staffName,
                auditorName: audit.auditorName,
                itemCount: audit.itemCount,
                notes: audit.notes,
                issue1: audit.issue1,
                issue2: audit.issue2,
                issue3: audit.issue3
            )
            
            try await auditRepository.update(updatedAudit)
            Logger.shared.success("Audit updated: \(updatedAudit.id)")
            
        } else {
            // Save new audit
            Logger.shared.info("Creating new audit")
            try await auditRepository.save(audit)
            Logger.shared.success("Audit saved: \(audit.id)")
        }
        
        // Log status
        Logger.shared.info("Audit status: \(audit.status.displayName)")
        if audit.hasIssues {
            Logger.shared.warning("Audit has \(audit.issueCount) issue(s)")
        }
    }
}

// MARK: - Errors

enum SaveAuditError: LocalizedError {
    case validationFailed(Error)
    case saveFailed
    case updateFailed
    
    var errorDescription: String? {
        switch self {
        case .validationFailed(let error):
            return "Validation failed: \(error.localizedDescription)"
        case .saveFailed:
            return "Failed to save audit"
        case .updateFailed:
            return "Failed to update audit"
        }
    }
}
