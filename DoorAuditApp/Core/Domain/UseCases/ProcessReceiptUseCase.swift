//
//  ProcessReceiptUseCase.swift
//  DoorAuditApp
//
//  Use Case for processing a receipt image
//  ENHANCED: Integrates document detection and perspective correction for flattened scans
//  Orchestrates: Image processing → Detect → Flatten → OCR → Barcode → Parsing → Saving
//  Created: December 2025
//

import Foundation
import UIKit
import AVFoundation

// MARK: - Process Receipt Use Case Protocol

/// Processes a receipt image and saves it
protocol ProcessReceiptUseCase {
    func execute(image: UIImage) async throws -> Receipt
}

// MARK: - Default Implementation

final class DefaultProcessReceiptUseCase: ProcessReceiptUseCase {
    
    // MARK: - Dependencies
    
    private let ocrService: OCRService
    private let barcodeService: BarcodeService
    private let documentDetectionService: DocumentDetectionService
    private let perspectiveCorrectionService: PerspectiveCorrectionService
    private let receiptRepository: ReceiptRepository
    private let imageRepository: ImageRepository
    
    // MARK: - Initialization
    
    init(
        ocrService: OCRService,
        barcodeService: BarcodeService,
        documentDetectionService: DocumentDetectionService,
        perspectiveCorrectionService: PerspectiveCorrectionService,
        receiptRepository: ReceiptRepository,
        imageRepository: ImageRepository
    ) {
        self.ocrService = ocrService
        self.barcodeService = barcodeService
        self.documentDetectionService = documentDetectionService
        self.perspectiveCorrectionService = perspectiveCorrectionService
        self.receiptRepository = receiptRepository
        self.imageRepository = imageRepository
    }
    
    // MARK: - Execute
    
    func execute(image: UIImage) async throws -> Receipt {
        Logger.shared.startOperation("Process Receipt")
        let startTime = Date()
        
        do {
            // Step 1: Fix orientation
            Logger.shared.info("Step 1: Fixing image orientation...")
            let orientationFixed = image.fixedOrientation()
            
            // Step 2: Detect receipt bounds and flatten perspective
            Logger.shared.info("Step 2: Detecting receipt bounds...")
            let correctedImage: UIImage
            if let detectedDocument = documentDetectionService.detectDocument(in: orientationFixed) {
                Logger.shared.success("Receipt bounds detected successfully")

                Logger.shared.info("Step 3: Correcting receipt perspective...")
                if let flattened = perspectiveCorrectionService.correctPerspective(
                    in: orientationFixed,
                    using: detectedDocument
                ) {
                    Logger.shared.success("Receipt perspective corrected successfully")
                    correctedImage = flattened
                } else {
                    Logger.shared.warning("Perspective correction failed, falling back to original image")
                    correctedImage = orientationFixed
                }
            } else {
                Logger.shared.info("No receipt detected, using full image")
                correctedImage = orientationFixed
            }
            
            // Step 4: Downscale for processing
            Logger.shared.info("Step 4: Downscaling image...")
            let processedImage = correctedImage.downscaled(maxDimension: AppConstants.ImageProcessing.maxDimension)
            Logger.shared.debug("Image processed: \(processedImage.size)")
            
            // Step 5: Extract text with OCR
            Logger.shared.info("Step 5: Extracting text with OCR...")
            let rawText = try await ocrService.extractText(from: processedImage)
            
            guard !rawText.isEmpty else {
                throw ProcessReceiptError.noTextExtracted
            }
            
            Logger.shared.info("Extracted \(rawText.count) characters of text")
            
            // Step 6: Parse receipt data from text
            Logger.shared.info("Step 6: Parsing receipt data...")
            let parsedData = ocrService.parseReceiptData(from: rawText)
            
            // Step 7: Detect barcode
            Logger.shared.info("Step 7: Detecting barcode...")
            let barcode = try? await barcodeService.detectBarcode(in: processedImage)
            
            if let barcode = barcode {
                Logger.shared.info("Barcode detected: \(barcode)")
            } else {
                Logger.shared.warning("No barcode detected")
            }
            
            // Step 8: Save image
            Logger.shared.info("Step 8: Saving image...")
            let imageID = try await saveImage(processedImage)
            
            // Step 9: Create receipt domain model
            Logger.shared.info("Step 9: Creating receipt...")
            let receipt = Receipt(
                timestamp: Date(),
                barcodeValue: barcode,
                storeName: parsedData.storeName ?? AppConstants.Store.name,
                purchaseDate: parsedData.date,
                totalAmount: parsedData.total,
                rawText: rawText,
                imageID: imageID,
                cashierNumber: parsedData.cashierNumber,
                registerNumber: parsedData.registerNumber,
                transactionNumber: parsedData.transactionNumber,
                memberID: parsedData.memberID,
                expectedItemCount: parsedData.expectedItemCount,
                lineItems: parsedData.lineItems
            )
            
            // Step 10: Validate receipt (soft validation - don't fail on missing fields)
            Logger.shared.info("Step 10: Validating receipt...")
            do {
                try receipt.validate()
            } catch {
                // Log validation issues but don't fail - we still want to save partial receipts
                Logger.shared.warning("Receipt validation warning: \(error.localizedDescription)")
            }
            
            // Step 11: Save to repository
            Logger.shared.info("Step 11: Saving receipt to database...")
            try await receiptRepository.save(receipt)
            
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.endOperation("Process Receipt", duration: duration)
            Logger.shared.success("Receipt processed successfully: \(receipt.id)")
            
            return receipt
            
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            Logger.shared.error("Receipt processing failed after \(String(format: "%.2f", duration))s", error: error)
            throw error
        }
    }
    
    // MARK: - Helper Methods
    
    /// Save image to repository
    private func saveImage(_ image: UIImage) async throws -> UUID {
        guard let imageData = image.jpegData(
            compressionQuality: AppConstants.ImageProcessing.jpegQuality
        ) else {
            throw ProcessReceiptError.imageCompressionFailed
        }
        
        let imageID = try await imageRepository.save(imageData)
        Logger.shared.info("Image saved: \(imageID), size: \(imageData.count) bytes")
        
        return imageID
    }
}

// MARK: - Parsed Receipt Data

/// Intermediate data structure for parsed receipt information
struct ParsedReceiptData {
    let storeName: String?
    let date: Date?
    let total: Double?
    let cashierNumber: String?
    let registerNumber: String?
    let transactionNumber: String?
    let memberID: String?
    let expectedItemCount: Int?
    let lineItems: [LineItem]
}

// MARK: - Errors

enum ProcessReceiptError: LocalizedError {
    case imageProcessingFailed
    case imageCompressionFailed
    case noTextExtracted
    case ocrFailed
    case barcodeFailed
    case parsingFailed
    case validationFailed
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .imageProcessingFailed:
            return "Failed to process image"
        case .imageCompressionFailed:
            return "Failed to compress image"
        case .noTextExtracted:
            return "No text found in image"
        case .ocrFailed:
            return "OCR processing failed"
        case .barcodeFailed:
            return "Barcode detection failed"
        case .parsingFailed:
            return "Failed to parse receipt data"
        case .validationFailed:
            return "Receipt validation failed"
        case .saveFailed:
            return "Failed to save receipt"
        }
    }
}

// MARK: - OCR Service Protocol

/// Protocol for OCR service
protocol OCRService {
    /// Extract text from image
    func extractText(from image: UIImage) async throws -> String
    
    /// Parse receipt data from text
    func parseReceiptData(from text: String) -> ParsedReceiptData
}

// MARK: - Barcode Service Protocol

/// Protocol for barcode detection
protocol BarcodeService {
    /// Detect barcode in image
    func detectBarcode(in image: UIImage) async throws -> String?
}

// MARK: - Document Detection Service Protocol

/// Protocol for document detection in receipt images
protocol DocumentDetectionService {
    /// Detect the most likely receipt/document quadrilateral in the image
    func detectDocument(in image: UIImage) -> DetectedDocument?
}

// MARK: - Perspective Correction Service Protocol

/// Protocol for scanner-style perspective correction
protocol PerspectiveCorrectionService {
    /// Warp the detected quadrilateral into a top-down flattened scan
    func correctPerspective(in image: UIImage, using document: DetectedDocument) -> UIImage?
}

// MARK: - Camera Service Protocol

/// Camera configuration for image picker
struct CameraConfiguration {
    let sourceType: UIImagePickerController.SourceType
    let allowsEditing: Bool
    let cameraCaptureMode: UIImagePickerController.CameraCaptureMode
    let cameraDevice: UIImagePickerController.CameraDevice
}

/// Protocol for camera service
protocol CameraService {
    /// Check if camera is available on the device
    func isCameraAvailable() -> Bool
    
    /// Request camera permission
    func requestCameraPermission() async -> Bool
    
    /// Check camera permission status
    func checkCameraPermission() -> AVAuthorizationStatus
    
    /// Get camera configuration for image picker
    func getCameraConfiguration() -> CameraConfiguration
}

// NOTE: ExportService protocol removed - use ExportAuditsUseCase instead
