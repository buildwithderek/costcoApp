//
//  ScanEnhancementMode.swift
//  DoorAuditApp
//
//  Scanner enhancement presets for review and OCR-friendly previewing
//  Created: March 2026
//

import Foundation

enum ScanEnhancementMode: String, CaseIterable, Identifiable, Sendable {
    case original
    case grayscale
    case highContrast
    case blackAndWhite
    case receipt

    var id: String { rawValue }

    var title: String {
        switch self {
        case .original:
            return "Color"
        case .grayscale:
            return "Gray"
        case .highContrast:
            return "Contrast"
        case .blackAndWhite:
            return "B&W"
        case .receipt:
            return "Receipt"
        }
    }

    var subtitle: String {
        switch self {
        case .original:
            return "Natural scan"
        case .grayscale:
            return "Reduce color noise"
        case .highContrast:
            return "Boost text edges"
        case .blackAndWhite:
            return "Bold document look"
        case .receipt:
            return "Thermal-paper tuned"
        }
    }
}
