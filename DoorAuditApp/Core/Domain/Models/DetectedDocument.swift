//
//  DetectedDocument.swift
//  DoorAuditApp
//
//  Normalized document detection model used by scanner services
//  Created: March 2026
//

import CoreGraphics

/// Normalized quadrilateral describing a detected document.
/// Points use Vision's normalized image-space coordinates (origin at bottom-left).
struct DetectedDocument: Sendable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    let confidence: Float

    /// Approximate normalized bounding box of the quadrilateral.
    var boundingBox: CGRect {
        let xs = [topLeft.x, topRight.x, bottomLeft.x, bottomRight.x]
        let ys = [topLeft.y, topRight.y, bottomLeft.y, bottomRight.y]

        guard let minX = xs.min(),
              let maxX = xs.max(),
              let minY = ys.min(),
              let maxY = ys.max() else {
            return .zero
        }

        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
}
