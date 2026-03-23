//
//  VisionDocumentScannerService.swift
//  DoorAuditApp
//
//  Vision-powered receipt detection and perspective correction
//  Created: March 2026
//

import UIKit
import Vision
import CoreImage
import ImageIO

/// Detects receipt bounds with Vision and produces flattened scans with Core Image.
final class VisionDocumentScannerService: DocumentDetectionService, PerspectiveCorrectionService {

    private let context = CIContext(options: nil)

    func detectDocument(in image: UIImage) -> DetectedDocument? {
        guard let cgImage = image.cgImage else {
            Logger.shared.warning("Document detection skipped: missing CGImage")
            return nil
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            let request = makeRectangleRequest()
            try handler.perform([request])
            return detectedDocument(from: request, logSuccess: true)

        } catch {
            Logger.shared.warning("Document detection failed: \(error.localizedDescription)")
            return nil
        }
    }

    func detectDocument(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation = .right
    ) -> DetectedDocument? {
        let request = makeRectangleRequest()
        let handler = VNImageRequestHandler(
            cvPixelBuffer: pixelBuffer,
            orientation: orientation,
            options: [:]
        )

        do {
            try handler.perform([request])
            return detectedDocument(from: request, logSuccess: false)
        } catch {
            Logger.shared.debug("Live document detection failed: \(error.localizedDescription)")
            return nil
        }
    }

    func correctPerspective(in image: UIImage, using document: DetectedDocument) -> UIImage? {
        guard let cgImage = image.cgImage else {
            Logger.shared.warning("Perspective correction skipped: missing CGImage")
            return nil
        }

        let ciImage = CIImage(cgImage: cgImage)
        let imageSize = CGSize(width: cgImage.width, height: cgImage.height)

        guard let filter = CIFilter(name: "CIPerspectiveCorrection") else {
            Logger.shared.error("Perspective correction filter unavailable")
            return nil
        }

        filter.setValue(ciImage, forKey: kCIInputImageKey)
        filter.setValue(CIVector(cgPoint: document.topLeft.scaled(to: imageSize)), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: document.topRight.scaled(to: imageSize)), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: document.bottomRight.scaled(to: imageSize)), forKey: "inputBottomRight")
        filter.setValue(CIVector(cgPoint: document.bottomLeft.scaled(to: imageSize)), forKey: "inputBottomLeft")

        guard let outputImage = filter.outputImage else {
            Logger.shared.warning("Perspective correction produced no output image")
            return nil
        }

        let normalizedOutput = outputImage.transformed(by: .identity)

        guard let correctedCGImage = context.createCGImage(normalizedOutput, from: normalizedOutput.extent) else {
            Logger.shared.warning("Failed to render perspective-corrected image")
            return nil
        }

        Logger.shared.info(
            "Perspective correction applied: \(correctedCGImage.width)x\(correctedCGImage.height)"
        )

        return UIImage(
            cgImage: correctedCGImage,
            scale: image.scale,
            orientation: .up
        )
    }

    private func makeRectangleRequest() -> VNDetectRectanglesRequest {
        let request = VNDetectRectanglesRequest()
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 0.85
        request.minimumSize = AppConstants.ImageProcessing.minDocumentSize
        request.minimumConfidence = AppConstants.ImageProcessing.minDocumentConfidence
        request.maximumObservations = 1
        request.quadratureTolerance = 20
        return request
    }

    private func detectedDocument(
        from request: VNDetectRectanglesRequest,
        logSuccess: Bool
    ) -> DetectedDocument? {
        guard let rectangle = request.results?.first else {
            Logger.shared.debug("No receipt quadrilateral detected")
            return nil
        }

        let detectedDocument = DetectedDocument(
            topLeft: rectangle.topLeft,
            topRight: rectangle.topRight,
            bottomLeft: rectangle.bottomLeft,
            bottomRight: rectangle.bottomRight,
            confidence: rectangle.confidence
        )

        if logSuccess {
            Logger.shared.info("Receipt quadrilateral detected with confidence \(String(format: "%.2f", rectangle.confidence))")
        }

        return detectedDocument
    }
}

private extension CGPoint {
    func scaled(to size: CGSize) -> CGPoint {
        CGPoint(
            x: x * size.width,
            y: y * size.height
        )
    }
}
