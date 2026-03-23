//
//  AppConstants.swift
//  L1 Demo
//
//  Application-wide constants
//  Created: December 2025
//

import Foundation
import CoreGraphics

enum AppConstants {
    
    // MARK: - Store Information
    
    enum Store {
        static let name = "COSTCO"
        static let location = "Signal Hill"
        static let number = "424"
        static let fullName = "\(name) - \(location) #\(number)"
    }
    
    // MARK: - Image Processing
    
    enum ImageProcessing {
        /// Maximum dimension for processed images (width or height)
        static let maxDimension: CGFloat = 1920
        
        /// JPEG compression quality (0.0 - 1.0)
        static let jpegQuality: CGFloat = 0.7
        
        /// Thumbnail size for list views
        static let thumbnailSize = CGSize(width: 100, height: 100)
        
        /// Preview size for detail views
        static let previewSize = CGSize(width: 400, height: 400)

        /// Minimum normalized size for a detected receipt/document
        static let minDocumentSize: Float = 0.15

        /// Minimum confidence for receipt/document detection
        static let minDocumentConfidence: Float = 0.6

        /// Minimum normalized area needed before live auto-capture is considered
        static let minLiveDocumentArea: CGFloat = 0.2

        /// Number of stable live-detection frames required before auto-capture
        static let stableFrameThreshold = 6

        /// Interval between live Vision analyses during camera preview
        static let liveDetectionInterval: TimeInterval = 0.12
    }
    
    // MARK: - Animation & Timing
    
    enum Animation {
        /// Standard animation duration
        static let standard: TimeInterval = 0.3
        
        /// Quick animation duration
        static let quick: TimeInterval = 0.15
        
        /// Slow animation duration
        static let slow: TimeInterval = 0.5
        
        /// Toast message display duration
        static let toastDuration: TimeInterval = 2.0
        
        /// Success message display duration
        static let successDuration: TimeInterval = 1.5
    }
    
    // MARK: - UI Configuration
    
    enum UI {
        /// Maximum items to show in "recent" lists
        static let maxRecentItems = 5
        
        /// Number of items per page for pagination
        static let itemsPerPage = 20
        
        /// Minimum swipe distance for gestures
        static let minSwipeDistance: CGFloat = 50
    }
    
    // MARK: - Data Validation
    
    enum Validation {
        /// Minimum receipt total amount
        static let minReceiptTotal: Double = 0.01
        
        /// Maximum receipt total amount
        static let maxReceiptTotal: Double = 99999.99
        
        /// Maximum characters for text fields
        static let maxTextFieldLength = 500
        
        /// Maximum barcode length
        static let maxBarcodeLength = 50
    }
    
    // MARK: - OCR Configuration
    
    enum OCR {
        /// Minimum confidence level for OCR text (0.0 - 1.0)
        static let minConfidence: Float = 0.5
        
        /// Languages to recognize
        static let recognitionLanguages = ["en-US"]
        
        /// Maximum processing time for OCR (seconds)
        static let maxProcessingTime: TimeInterval = 10.0
    }
    
    // MARK: - Export Configuration
    
    enum Export {
        /// Default CSV filename prefix
        static let csvFilenamePrefix = "Costco_Audit"
        
        /// Default ZIP filename prefix
        static let zipFilenamePrefix = "Costco_Audit_Bundle"
        
        /// Date format for export filenames
        static let filenameDateFormat = "yyyy-MM-dd_HHmm"
        
        /// CSV delimiter
        static let csvDelimiter = ","
        
        /// Include header row in CSV
        static let includeCSVHeaders = true
    }
    
    // MARK: - Date Formats
    
    enum DateFormat {
        /// Display format: "Jan 15, 2025"
        static let display = "MMM d, yyyy"
        
        /// Display with time: "Jan 15, 2025 at 2:30 PM"
        static let displayWithTime = "MMM d, yyyy 'at' h:mm a"
        
        /// Short format: "1/15/25"
        static let short = "M/d/yy"
        
        /// Receipt format: "01/15/2025"
        static let receipt = "MM/dd/yyyy"
        
        /// Receipt with time: "01/15/2025 14:30:45"
        static let receiptWithTime = "MM/dd/yyyy HH:mm:ss"
        
        /// Time only: "2:30 PM"
        static let timeOnly = "h:mm a"
        
        /// ISO 8601: "2025-01-15T14:30:45Z"
        static let iso8601 = "yyyy-MM-dd'T'HH:mm:ssZ"
    }
    
    // MARK: - Persistence
    
    enum Persistence {
        /// SwiftData model version
        static let modelVersion = "1.0.0"
        
        /// Enable CloudKit sync
        static let enableCloudSync = false
        
        /// Auto-save interval (seconds)
        static let autoSaveInterval: TimeInterval = 30.0
    }
    
    // MARK: - Feature Flags
    
    enum Features {
        /// Enable advanced audit mode
        static let enableAdvancedAudit = true
        
        /// Enable image editing
        static let enableImageEditing = false
        
        /// Enable batch export
        static let enableBatchExport = true
        
        /// Enable receipt text search
        static let enableTextSearch = true
    }
}

// MARK: - Convenience Accessors

extension AppConstants {
    /// Current app version from bundle
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    /// Current build number from bundle
    static var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
    
    /// Full version string: "1.0.0 (1)"
    static var fullVersion: String {
        "\(appVersion) (\(buildNumber))"
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted when receipts are added, deleted, or updated
    /// Used to sync views that display receipt data
    static let receiptsDidChange = Notification.Name("receiptsDidChange")
}
