//
//  VisionBarcodeService.swift
//  L1 Demo
//
//  Barcode detection service using Apple's Vision framework
//  Wraps ReceiptBarcodeDetector into Clean Architecture
//  Created: December 2025
//

import UIKit
import Vision

/// Implementation of BarcodeService using Apple's Vision framework
/// Wraps your existing ReceiptBarcodeDetector code
final class VisionBarcodeService: BarcodeService {
    
    // MARK: - Configuration
    
    private let supportedSymbologies: [VNBarcodeSymbology] = [
        .code128,
        .code39,
        .code93,
        .ean13,
        .ean8,
        .upce,
        .pdf417,
        .qr,
        .dataMatrix,
        .i2of5
    ]
    
    // MARK: - BarcodeService Protocol Implementation
    
    func detectBarcode(in image: UIImage) async throws -> String? {
        Logger.shared.info("Starting barcode detection...")
        
        guard let cgImage = image.cgImage else {
            Logger.shared.error("Invalid image for barcode detection")
            throw BarcodeError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    Logger.shared.error("Barcode detection failed", error: error)
                    continuation.resume(throwing: BarcodeError.detectionFailed(error))
                    return
                }
                
                // Get the first barcode result
                guard let results = request.results as? [VNBarcodeObservation],
                      let firstBarcode = results.first,
                      let payload = firstBarcode.payloadStringValue else {
                    Logger.shared.warning("No barcode found in image")
                    continuation.resume(returning: nil)
                    return
                }
                
                Logger.shared.success("Barcode detected: \(payload)")
                continuation.resume(returning: payload)
            }
            
            // Configure to detect common receipt barcode types
            request.symbologies = self.supportedSymbologies
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                Logger.shared.error("Barcode request failed", error: error)
                continuation.resume(throwing: BarcodeError.detectionFailed(error))
            }
        }
    }
    
    /// Detect all barcodes in the image (useful for debugging)
    func detectAllBarcodes(in image: UIImage) async throws -> [String] {
        Logger.shared.info("Detecting all barcodes...")
        
        guard let cgImage = image.cgImage else {
            throw BarcodeError.invalidImage
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNDetectBarcodesRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: BarcodeError.detectionFailed(error))
                    return
                }
                
                guard let results = request.results as? [VNBarcodeObservation] else {
                    continuation.resume(returning: [])
                    return
                }
                
                let barcodes = results.compactMap { $0.payloadStringValue }
                Logger.shared.info("Found \(barcodes.count) barcodes")
                continuation.resume(returning: barcodes)
            }
            
            request.symbologies = self.supportedSymbologies
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: BarcodeError.detectionFailed(error))
            }
        }
    }
}

// MARK: - Barcode Errors

enum BarcodeError: LocalizedError {
    case invalidImage
    case detectionFailed(Error)
    case noBarcodeFound
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image for barcode detection"
        case .detectionFailed(let error):
            return "Barcode detection failed: \(error.localizedDescription)"
        case .noBarcodeFound:
            return "No barcode found in image"
        }
    }
}
