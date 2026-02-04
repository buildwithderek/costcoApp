//
//  DeleteReceiptUseCase.swift
//  L1 Demo
//
//  Use Case for deleting receipts
//  Handles cascade deletion of related data (audit, image)
//  Created: December 2025
//

import Foundation

/// Deletes a receipt and all related data
protocol DeleteReceiptUseCase {
    func execute(receiptID: UUID) async throws
    func execute(receipt: Receipt) async throws
    func deleteMultiple(receiptIDs: [UUID]) async throws
}

final class DefaultDeleteReceiptUseCase: DeleteReceiptUseCase {
    
    // MARK: - Dependencies
    
    private let receiptRepository: ReceiptRepository
    private let auditRepository: AuditRepository
    private let imageRepository: ImageRepository
    
    // MARK: - Initialization
    
    init(
        receiptRepository: ReceiptRepository,
        auditRepository: AuditRepository,
        imageRepository: ImageRepository
    ) {
        self.receiptRepository = receiptRepository
        self.auditRepository = auditRepository
        self.imageRepository = imageRepository
    }
    
    // MARK: - Execute
    
    func execute(receiptID: UUID) async throws {
        Logger.shared.info("Deleting receipt: \(receiptID)")
        
        // Fetch receipt to get image ID
        guard let receipt = try await receiptRepository.fetch(id: receiptID) else {
            Logger.shared.warning("Receipt not found: \(receiptID)")
            throw DeleteReceiptError.receiptNotFound
        }
        
        try await execute(receipt: receipt)
    }
    
    func execute(receipt: Receipt) async throws {
        Logger.shared.info("Deleting receipt and related data: \(receipt.id)")
        
        do {
            // Step 1: Delete related audit (if exists)
            Logger.shared.debug("Deleting audit for receipt...")
            try? await auditRepository.deleteAudits(for: receipt.id)
            
            // Step 2: Delete image (if exists)
            if let imageID = receipt.imageID {
                Logger.shared.debug("Deleting image: \(imageID)")
                try? await imageRepository.delete(id: imageID)
            }
            
            // Step 3: Delete receipt
            Logger.shared.debug("Deleting receipt from database...")
            try await receiptRepository.delete(receipt)
            
            Logger.shared.success("Receipt deleted successfully: \(receipt.id)")
            
            // Step 4: Notify other views that receipts changed
            await MainActor.run {
                NotificationCenter.default.post(name: .receiptsDidChange, object: nil)
            }
            
        } catch {
            Logger.shared.error("Failed to delete receipt", error: error)
            throw DeleteReceiptError.deleteFailed(error)
        }
    }
    
    func deleteMultiple(receiptIDs: [UUID]) async throws {
        Logger.shared.info("Deleting \(receiptIDs.count) receipts...")
        
        var deletedCount = 0
        var errors: [Error] = []
        
        for receiptID in receiptIDs {
            do {
                try await execute(receiptID: receiptID)
                deletedCount += 1
            } catch {
                Logger.shared.error("Failed to delete receipt \(receiptID)", error: error)
                errors.append(error)
            }
        }
        
        if deletedCount > 0 {
            Logger.shared.success("Deleted \(deletedCount) receipts")
        }
        
        if !errors.isEmpty {
            Logger.shared.warning("Failed to delete \(errors.count) receipts")
            throw DeleteReceiptError.partialFailure(
                succeeded: deletedCount,
                failed: errors.count
            )
        }
    }
}

// MARK: - Errors

enum DeleteReceiptError: LocalizedError {
    case receiptNotFound
    case deleteFailed(Error)
    case partialFailure(succeeded: Int, failed: Int)
    
    var errorDescription: String? {
        switch self {
        case .receiptNotFound:
            return "Receipt not found"
        case .deleteFailed(let error):
            return "Delete failed: \(error.localizedDescription)"
        case .partialFailure(let succeeded, let failed):
            return "Deleted \(succeeded) receipts, failed to delete \(failed)"
        }
    }
}
