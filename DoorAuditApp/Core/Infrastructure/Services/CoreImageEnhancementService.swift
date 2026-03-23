//
//  CoreImageEnhancementService.swift
//  DoorAuditApp
//
//  Scanner-style enhancement presets powered by Core Image
//  Created: March 2026
//

import UIKit
import CoreImage

protocol ImageEnhancementService {
    func enhance(_ image: UIImage, mode: ScanEnhancementMode) -> UIImage?
}

final class CoreImageEnhancementService: ImageEnhancementService {
    private let context = CIContext(options: nil)

    func enhance(_ image: UIImage, mode: ScanEnhancementMode) -> UIImage? {
        guard mode != .original else { return image }
        guard let cgImage = image.cgImage else {
            Logger.shared.warning("Image enhancement skipped: missing CGImage")
            return nil
        }

        let inputImage = CIImage(cgImage: cgImage)
        let outputImage: CIImage?

        switch mode {
        case .original:
            outputImage = inputImage
        case .grayscale:
            outputImage = grayscale(from: inputImage)
        case .highContrast:
            outputImage = highContrast(from: inputImage)
        case .blackAndWhite:
            outputImage = blackAndWhite(from: inputImage)
        case .receipt:
            outputImage = receiptOptimized(from: inputImage)
        }

        guard let outputImage,
              let renderedImage = context.createCGImage(outputImage, from: outputImage.extent) else {
            Logger.shared.warning("Failed to render enhanced image for mode \(mode.rawValue)")
            return nil
        }

        return UIImage(cgImage: renderedImage, scale: image.scale, orientation: .up)
    }

    private func grayscale(from image: CIImage) -> CIImage? {
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(image, forKey: kCIInputImageKey)
        controls?.setValue(0.0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.0, forKey: kCIInputBrightnessKey)
        controls?.setValue(1.05, forKey: kCIInputContrastKey)
        return controls?.outputImage
    }

    private func highContrast(from image: CIImage) -> CIImage? {
        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(image, forKey: kCIInputImageKey)
        controls?.setValue(0.0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.25, forKey: kCIInputContrastKey)
        controls?.setValue(0.02, forKey: kCIInputBrightnessKey)

        let exposure = CIFilter(name: "CIExposureAdjust")
        exposure?.setValue(controls?.outputImage, forKey: kCIInputImageKey)
        exposure?.setValue(0.35, forKey: kCIInputEVKey)
        return exposure?.outputImage
    }

    private func blackAndWhite(from image: CIImage) -> CIImage? {
        let monochrome = CIFilter(name: "CIPhotoEffectNoir")
        monochrome?.setValue(image, forKey: kCIInputImageKey)

        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(monochrome?.outputImage, forKey: kCIInputImageKey)
        controls?.setValue(0.0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.45, forKey: kCIInputContrastKey)
        controls?.setValue(0.05, forKey: kCIInputBrightnessKey)

        return controls?.outputImage
    }

    private func receiptOptimized(from image: CIImage) -> CIImage? {
        let base = blackAndWhite(from: image) ?? image

        let sharpen = CIFilter(name: "CISharpenLuminance")
        sharpen?.setValue(base, forKey: kCIInputImageKey)
        sharpen?.setValue(0.55, forKey: kCIInputSharpnessKey)

        let controls = CIFilter(name: "CIColorControls")
        controls?.setValue(sharpen?.outputImage, forKey: kCIInputImageKey)
        controls?.setValue(0.0, forKey: kCIInputSaturationKey)
        controls?.setValue(1.55, forKey: kCIInputContrastKey)
        controls?.setValue(0.03, forKey: kCIInputBrightnessKey)

        return controls?.outputImage
    }
}
