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

    var area: CGFloat {
        boundingBox.width * boundingBox.height
    }

    var center: CGPoint {
        CGPoint(x: boundingBox.midX, y: boundingBox.midY)
    }
}

enum DocumentCorner: CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight

    var id: Self { self }
}

extension DetectedDocument {
    static func defaultDocument(inset: CGFloat = 0.08) -> DetectedDocument {
        let clampedInset = min(max(inset, 0.0), 0.45)

        return DetectedDocument(
            topLeft: CGPoint(x: clampedInset, y: 1.0 - clampedInset),
            topRight: CGPoint(x: 1.0 - clampedInset, y: 1.0 - clampedInset),
            bottomLeft: CGPoint(x: clampedInset, y: clampedInset),
            bottomRight: CGPoint(x: 1.0 - clampedInset, y: clampedInset),
            confidence: 0
        )
    }

    func point(for corner: DocumentCorner) -> CGPoint {
        switch corner {
        case .topLeft:
            topLeft
        case .topRight:
            topRight
        case .bottomLeft:
            bottomLeft
        case .bottomRight:
            bottomRight
        }
    }

    func updating(_ corner: DocumentCorner, to point: CGPoint) -> DetectedDocument {
        switch corner {
        case .topLeft:
            DetectedDocument(
                topLeft: point,
                topRight: topRight,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight,
                confidence: confidence
            )
        case .topRight:
            DetectedDocument(
                topLeft: topLeft,
                topRight: point,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight,
                confidence: confidence
            )
        case .bottomLeft:
            DetectedDocument(
                topLeft: topLeft,
                topRight: topRight,
                bottomLeft: point,
                bottomRight: bottomRight,
                confidence: confidence
            )
        case .bottomRight:
            DetectedDocument(
                topLeft: topLeft,
                topRight: topRight,
                bottomLeft: bottomLeft,
                bottomRight: point,
                confidence: confidence
            )
        }
    }
}
