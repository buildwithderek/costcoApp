//
//  ReceiptCaptureViewModel.swift
//  DoorAuditApp
//
//  ViewModel for receipt capture and main screen
//  Handles: Camera capture, OCR processing, today's receipts list
//  Created: December 2025
//

import Foundation
import SwiftUI
import UIKit

@Observable
final class ReceiptCaptureViewModel {
    
    // MARK: - State
    
    var todaysReceipts: [Receipt] = []
    var allReceiptsCount: Int = 0
    var completedCount: Int = 0
    
    var isProcessing = false
    var error: Error?
    
    // Navigation state
    var capturedReceipt: Receipt?
    var shouldNavigateToAudit = false
    
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
    }
    
    // MARK: - Actions
    
    /// Capture and process a receipt image
    @MainActor
    func captureReceipt(_ image: UIImage) async {
        isProcessing = true
        error = nil
        
        do {
            Logger.shared.info("Processing captured receipt...")
            
            // Process the receipt image (OCR, parsing, saving)
            let receipt = try await processReceipt.execute(image: image)
            
            // Set up for navigation
            capturedReceipt = receipt
            shouldNavigateToAudit = true
            
            // Reload today's receipts
            await loadTodaysReceipts()
            
            Logger.shared.success("Receipt captured: \(receipt.id)")
            
        } catch {
            Logger.shared.error("Failed to process receipt", error: error)
            self.error = error
        }
        
        isProcessing = false
    }
    
    /// Load today's receipts
    @MainActor
    func loadTodaysReceipts() async {
        do {
            // Fetch today's receipts
            todaysReceipts = try await fetchReceipts.fetchTodaysReceipts()
            
            // Fetch total count
            allReceiptsCount = try await fetchReceipts.count()
            
            // Count completed audits (simplified - count where audit exists)
            // Note: In production, you'd query the audit repository
            completedCount = 0
            
            Logger.shared.info("Loaded \(todaysReceipts.count) receipts for today")
            
        } catch {
            Logger.shared.error("Failed to load receipts", error: error)
            self.error = error
        }
    }
    
    /// Delete a receipt
    @MainActor
    func deleteReceipt(_ receipt: Receipt) async {
        do {
            try await deleteReceipt.execute(receipt: receipt)
            
            // Remove from local list
            todaysReceipts.removeAll { $0.id == receipt.id }
            allReceiptsCount = max(0, allReceiptsCount - 1)
            
            Logger.shared.success("Receipt deleted: \(receipt.id)")
            
        } catch {
            Logger.shared.error("Failed to delete receipt", error: error)
            self.error = error
        }
    }
    
    /// Called after navigation to audit view
    func didNavigateToAudit() {
        shouldNavigateToAudit = false
        capturedReceipt = nil
    }
    
    /// Clear error
    func clearError() {
        error = nil
    }
    
    // MARK: - Camera Helpers
    
    /// Check if camera is available
    func isCameraAvailable() -> Bool {
        cameraService.isCameraAvailable()
    }
    
    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        await cameraService.requestCameraPermission()
    }
}
