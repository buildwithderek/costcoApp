//
//  ReceiptCaptureViewModel.swift
//  DoorAuditApp
//
//  ViewModel for receipt capture and processing
//  Handles camera capture, image processing, and navigation to audit
//  Created: December 2025
//

import Foundation
import SwiftUI
import Observation

/// ViewModel for receipt capture screen
@Observable
final class ReceiptCaptureViewModel {
    
    // MARK: - State
    
    var isProcessing = false
    var error: Error?
    
    // Navigation
    var shouldNavigateToAudit = false
    var capturedReceipt: Receipt?
    
    // Today's receipts
    var todaysReceipts: [Receipt] = []
    var allReceiptsCount: Int = 0
    
    // MARK: - Computed Properties
    
    var completedCount: Int {
        // This would need audit repository to check completed status
        // For now, return count of receipts (placeholder)
        todaysReceipts.count
    }
    
    // MARK: - Dependencies
    
    private let processReceipt: ProcessReceiptUseCase
    private let fetchReceipts: FetchReceiptsUseCase
    private let deleteReceipt: DeleteReceiptUseCase
    private let cameraService: CameraService
    
    // MARK: - Initialization
    
    init(
        processReceipt: ProcessReceiptUseCase,
        fetchReceipts: FetchReceiptsUseCase,
        deleteReceipt: DeleteReceiptUseCase,
        cameraService: CameraService
    ) {
        self.processReceipt = processReceipt
        self.fetchReceipts = fetchReceipts
        self.deleteReceipt = deleteReceipt
        self.cameraService = cameraService
        
        Logger.shared.info("ReceiptCaptureViewModel initialized")
    }
    
    // MARK: - Actions
    
    /// Capture and process a receipt image
    @MainActor
    func captureReceipt(_ image: UIImage) async {
        Logger.shared.info("📸 captureReceipt called with image size: \(image.size)")
        
        isProcessing = true
        error = nil
        
        do {
            Logger.shared.info("📸 Step 1: Calling processReceipt.execute()...")
            
            // Process the receipt image (OCR, parse, save)
            let receipt = try await processReceipt.execute(image: image)
            
            Logger.shared.success("📸 Step 2: Receipt processed successfully!")
            Logger.shared.info("📸 Receipt ID: \(receipt.id)")
            Logger.shared.info("📸 Line items count: \(receipt.lineItems.count)")
            Logger.shared.info("📸 Expected items: \(receipt.expectedItemCount ?? -1)")
            Logger.shared.info("📸 Total amount: $\(receipt.totalAmount ?? 0)")
            Logger.shared.info("📸 Register: \(receipt.registerNumber ?? "nil")")
            Logger.shared.info("📸 Transaction: \(receipt.transactionNumber ?? "nil")")
            
            // Log each line item
            for (index, item) in receipt.lineItems.enumerated() {
                Logger.shared.debug("📸 LineItem[\(index)]: \(item.description) - $\(item.price ?? 0)")
            }
            
            // Set captured receipt for navigation
            Logger.shared.info("📸 Step 3: Setting capturedReceipt...")
            self.capturedReceipt = receipt
            
            Logger.shared.info("📸 Step 4: Setting shouldNavigateToAudit = true...")
            self.shouldNavigateToAudit = true
            
            // Reload today's receipts
            Logger.shared.info("📸 Step 5: Reloading today's receipts...")
            await loadTodaysReceipts()
            
            isProcessing = false
            Logger.shared.success("📸 captureReceipt completed successfully!")
            
        } catch {
            Logger.shared.error("📸 captureReceipt FAILED", error: error)
            self.error = error
            isProcessing = false
        }
    }
    
    /// Load today's receipts
    @MainActor
    func loadTodaysReceipts() async {
        do {
            todaysReceipts = try await fetchReceipts.fetchTodaysReceipts()
            allReceiptsCount = try await fetchReceipts.count()
            
            Logger.shared.info("Loaded \(todaysReceipts.count) receipts for today, total: \(allReceiptsCount)")
            
        } catch {
            Logger.shared.error("Failed to load today's receipts", error: error)
        }
    }
    
    /// Delete a receipt
    @MainActor
    func deleteReceipt(_ receipt: Receipt) async {
        do {
            try await deleteReceipt.execute(receipt: receipt)
            
            // Remove from local array
            todaysReceipts.removeAll { $0.id == receipt.id }
            allReceiptsCount = max(0, allReceiptsCount - 1)
            
            Logger.shared.success("Receipt deleted: \(receipt.id)")
            
        } catch {
            Logger.shared.error("Failed to delete receipt", error: error)
            self.error = error
        }
    }
    func removeReceiptLocally(id: UUID) {
        todaysReceipts.removeAll { $0.id == id }
        // Also update allReceiptsCount if you track it
        if allReceiptsCount > 0 {
            allReceiptsCount -= 1
        }
        Logger.shared.debug("ReceiptCaptureVM: Removed receipt locally: \(id)")
    }
    /// Called after navigation to audit
    func didNavigateToAudit() {
        Logger.shared.info("📸 didNavigateToAudit called - receipt has \(capturedReceipt?.lineItems.count ?? 0) items")
        shouldNavigateToAudit = false
    }
    
    /// Clear error
    func clearError() {
        error = nil
    }
}
