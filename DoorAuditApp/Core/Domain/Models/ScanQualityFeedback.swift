//
//  ScanQualityFeedback.swift
//  DoorAuditApp
//
//  Image-quality analysis results for scanner capture guidance
//  Created: March 2026
//

import Foundation

enum ScanQualityIssue: String, CaseIterable, Identifiable, Sendable {
    case tooDark
    case tooBright
    case blurry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tooDark:
            return "Low light"
        case .tooBright:
            return "Washed out"
        case .blurry:
            return "Blurry"
        }
    }
}

struct ScanQualityFeedback: Sendable {
    let brightnessScore: Double
    let sharpnessScore: Double
    let issues: [ScanQualityIssue]

    var shouldRetake: Bool {
        !issues.isEmpty
    }

    var summary: String {
        if issues.isEmpty {
            return "Looks good for OCR."
        }

        return issues.map(\.title).joined(separator: " • ")
    }
}
