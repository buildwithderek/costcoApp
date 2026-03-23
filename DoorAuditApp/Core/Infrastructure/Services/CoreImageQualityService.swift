//
//  CoreImageQualityService.swift
//  DoorAuditApp
//
//  Blur and lighting heuristics for scanner guidance and retake feedback
//  Created: March 2026
//

import UIKit
import CoreImage

protocol ImageQualityService {
    func analyze(_ image: UIImage) -> ScanQualityFeedback?
    func analyze(pixelBuffer: CVPixelBuffer) -> ScanQualityFeedback?
}

final class CoreImageQualityService: ImageQualityService {
    private let context = CIContext(options: nil)
    private let colorSpace = CGColorSpaceCreateDeviceRGB()

    func analyze(_ image: UIImage) -> ScanQualityFeedback? {
        guard let cgImage = image.cgImage else {
            Logger.shared.warning("Image quality analysis skipped: missing CGImage")
            return nil
        }

        return analyze(ciImage: CIImage(cgImage: cgImage))
    }

    func analyze(pixelBuffer: CVPixelBuffer) -> ScanQualityFeedback? {
        analyze(ciImage: CIImage(cvPixelBuffer: pixelBuffer))
    }

    private func analyze(ciImage: CIImage) -> ScanQualityFeedback? {
        guard !ciImage.extent.isEmpty,
              let brightnessScore = averageIntensity(for: ciImage),
              let sharpnessScore = averageEdgeStrength(for: ciImage) else {
            return nil
        }

        var issues: [ScanQualityIssue] = []

        if brightnessScore < AppConstants.ImageProcessing.minLiveBrightness {
            issues.append(.tooDark)
        } else if brightnessScore > AppConstants.ImageProcessing.maxLiveBrightness {
            issues.append(.tooBright)
        }

        if sharpnessScore < AppConstants.ImageProcessing.minSharpnessScore {
            issues.append(.blurry)
        }

        return ScanQualityFeedback(
            brightnessScore: brightnessScore,
            sharpnessScore: sharpnessScore,
            issues: issues
        )
    }

    private func averageIntensity(for image: CIImage) -> Double? {
        let grayscaleFilter = CIFilter(name: "CIColorControls")
        grayscaleFilter?.setValue(image, forKey: kCIInputImageKey)
        grayscaleFilter?.setValue(0.0, forKey: kCIInputSaturationKey)

        return averageRGBA(for: grayscaleFilter?.outputImage)?.luma
    }

    private func averageEdgeStrength(for image: CIImage) -> Double? {
        let grayscaleFilter = CIFilter(name: "CIColorControls")
        grayscaleFilter?.setValue(image, forKey: kCIInputImageKey)
        grayscaleFilter?.setValue(0.0, forKey: kCIInputSaturationKey)

        let edgesFilter = CIFilter(name: "CIEdges")
        edgesFilter?.setValue(grayscaleFilter?.outputImage, forKey: kCIInputImageKey)
        edgesFilter?.setValue(3.0, forKey: kCIInputIntensityKey)

        return averageRGBA(for: edgesFilter?.outputImage)?.luma
    }

    private func averageRGBA(for image: CIImage?) -> (red: Double, green: Double, blue: Double, alpha: Double, luma: Double)? {
        guard let image else { return nil }

        let averageFilter = CIFilter(name: "CIAreaAverage")
        averageFilter?.setValue(image, forKey: kCIInputImageKey)
        averageFilter?.setValue(CIVector(cgRect: image.extent), forKey: kCIInputExtentKey)

        guard let outputImage = averageFilter?.outputImage else { return nil }

        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: colorSpace
        )

        let red = Double(bitmap[0]) / 255.0
        let green = Double(bitmap[1]) / 255.0
        let blue = Double(bitmap[2]) / 255.0
        let alpha = Double(bitmap[3]) / 255.0
        let luma = (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)

        return (red, green, blue, alpha, luma)
    }
}
