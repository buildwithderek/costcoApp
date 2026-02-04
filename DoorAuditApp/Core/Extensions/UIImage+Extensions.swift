//
//  UIImage+Extensions.swift
//  L1 Demo
//
//  UIImage helper extensions
//  Created: December 2025
//

import UIKit

extension UIImage {
    /// Resize image to specified size
    func resized(to size: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        return UIGraphicsGetImageFromCurrentImageContext()
    }
    
    /// Fix image orientation
    func fixedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: size))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
    
    /// Downscale image to max dimension
    func downscaled(maxDimension: CGFloat) -> UIImage {
        let maxSize = max(size.width, size.height)
        
        guard maxSize > maxDimension else { return self }
        
        let scale = maxDimension / maxSize
        let newSize = CGSize(
            width: size.width * scale,
            height: size.height * scale
        )
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, self.scale)
        defer { UIGraphicsEndImageContext() }
        draw(in: CGRect(origin: .zero, size: newSize))
        
        return UIGraphicsGetImageFromCurrentImageContext() ?? self
    }
}
