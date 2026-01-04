//
//  ProcessReceiptUseCase.swift
//  DoorAuditApp
//
//  Use Case for processing a receipt image
//  ENHANCED: Integrates ReceiptCropper for auto-crop to receipt bounds
//  Orchestrates: Image processing → Auto-crop → OCR → Barcode → Parsing → Saving
//  Created: December 2025
//

import Foundation
import UIKit
import AVFoundation
import Vision

// MARK: - Receipt Cropper

/// Auto-crops images to detected receipt bounds using Vision framework
enum ReceiptCropper {
    
    /// Crop image to detected receipt bounds
    /// Returns nil if no receipt detected (use original image)
    static func cropToReceipt(_ image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2   // Receipts are tall and narrow
        request.maximumAspectRatio = 0.8
        request.minimumSize = 0.15          // At least 15% of image
        request.minimumConfidence = 0.6
        request.maximumObservations = 1
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
            
            guard let observation = request.results?.first else {
                Logger.shared.debug("No receipt rectangle detected")
                return nil
            }
            
            // Convert to image coordinates
            let imageWidth = CGFloat(cgImage.width)
            let imageHeight = CGFloat(cgImage.height)
            
            // Use bounding box for simple crop
            let bbox = observation.boundingBox
            let cropRect = CGRect(
                x: bbox.minX * imageWidth,
                y: (1 - bbox.maxY) * imageHeight,
                width: bbox.width * imageWidth,
                height: bbox.height * imageHeight
            )
            
            // Add some padding
            let padding: CGFloat = 10
            let paddedRect = cropRect.insetBy(dx: -padding, dy: -padding)
            
            // Ensure rect is within bounds
            let clampedRect = paddedRect.intersection(CGRect(x: 0, y: 0, width: imageWidth, height: imageHeight))
            
            guard let croppedCGImage = cgImage.cropping(to: clampedRect) else {
                return nil
            }
            
            Logger.shared.info("Receipt cropped: \(Int(clampedRect.width))x\(Int(clampedRect.height))")
            return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
            
        } catch {
            Logger.shared.warning("Receipt crop failed: \(error.localizedDescription)")
            return nil
        }
    }
}

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
    private let receiptRepository: ReceiptRepository
    private let imageRepository: ImageRepository
    
    // MARK: - Initialization
    
    init(
        ocrService: OCRService,
        barcodeService: BarcodeService,
        receiptRepository: ReceiptRepository,
        imageRepository: ImageRepository
    ) {
        self.ocrService = ocrService
        self.barcodeService = barcodeService
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
            
            // Step 2: Auto-crop to receipt bounds (NEW!)
            Logger.shared.info("Step 2: Auto-cropping to receipt bounds...")
            let croppedImage: UIImage
            if let cropped = ReceiptCropper.cropToReceipt(orientationFixed) {
                Logger.shared.success("Receipt auto-cropped successfully")
                croppedImage = cropped
            } else {
                Logger.shared.info("No receipt detected, using full image")
                croppedImage = orientationFixed
            }
            
            // Step 3: Downscale for processing
            Logger.shared.info("Step 3: Downscaling image...")
            let processedImage = croppedImage.downscaled(maxDimension: AppConstants.ImageProcessing.maxDimension)
            Logger.shared.debug("Image processed: \(processedImage.size)")
            
            // Step 4: Extract text with OCR
            Logger.shared.info("Step 4: Extracting text with OCR...")
            let rawText = try await ocrService.extractText(from: processedImage)
            
            guard !rawText.isEmpty else {
                throw ProcessReceiptError.noTextExtracted
            }
            
            Logger.shared.info("Extracted \(rawText.count) characters of text")
            
            // Step 5: Parse receipt data from text
            Logger.shared.info("Step 5: Parsing receipt data...")
            let parsedData = ocrService.parseReceiptData(from: rawText)
            
            // Step 6: Detect barcode
            Logger.shared.info("Step 6: Detecting barcode...")
            let barcode = try? await barcodeService.detectBarcode(in: processedImage)
            
            if let barcode = barcode {
                Logger.shared.info("Barcode detected: \(barcode)")
            } else {
                Logger.shared.warning("No barcode detected")
            }
            
            // Step 7: Save image
            Logger.shared.info("Step 7: Saving image...")
            let imageID = try await saveImage(processedImage)
            
            // Step 8: Create receipt domain model
            Logger.shared.info("Step 8: Creating receipt...")
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
            
            // Step 9: Validate receipt (soft validation - don't fail on missing fields)
            Logger.shared.info("Step 9: Validating receipt...")
            do {
                try receipt.validate()
            } catch {
                // Log validation issues but don't fail - we still want to save partial receipts
                Logger.shared.warning("Receipt validation warning: \(error.localizedDescription)")
            }
            
            // Step 10: Save to repository
            Logger.shared.info("Step 10: Saving receipt to database...")
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

// MARK: - Export Service Protocol

/// Protocol for export service
protocol ExportService {
    // Export functionality defined in CSVExportService
}
