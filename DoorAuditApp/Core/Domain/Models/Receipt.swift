//
//  Receipt.swift
//  L1 Demo
//
//  Domain model for Receipt (Pure Swift - No SwiftData)
//  Represents business logic for a receipt
//  Created: December 2025
//

import Foundation
import Foundation
import SwiftData
import UIKit

/// Pure business entity representing a receipt
/// No persistence concerns - completely framework-agnostic
struct Receipt: Identifiable, Hashable {
    
    // MARK: - Identity
    
    let id: UUID
    let timestamp: Date
    
    // MARK: - Receipt Information
    
    let barcodeValue: String?
    let storeName: String?
    let purchaseDate: Date?
    let totalAmount: Double?
    let rawText: String
    
    // MARK: - Image
    
    let imageID: UUID?
    
    // MARK: - Transaction Details
    
    let cashierNumber: String?
    let registerNumber: String?
    let transactionNumber: String?
    let memberID: String?
    
    // MARK: - Items
    
    let expectedItemCount: Int?
    let lineItems: [LineItem]
    
    // MARK: - Computed Properties
    
    var hasImage: Bool {
        imageID != nil
    }
    
    var hasBarcode: Bool {
        barcodeValue != nil && !(barcodeValue?.isEmpty ?? true)
    }
    
    var hasTotal: Bool {
        totalAmount != nil && (totalAmount ?? 0) > 0
    }
    
    var formattedTotal: String? {
        guard let amount = totalAmount else { return nil }
        return String(format: "$%.2f", amount)
    }
    
    var displayDate: String {
        (purchaseDate ?? timestamp).displayString
    }
    
    var displayTime: String {
        timestamp.displayStringWithTime
    }
    
    var shortDescription: String {
        var parts: [String] = []
        
        if let register = registerNumber {
            parts.append("Reg \(register)")
        }
        
        if let transaction = transactionNumber {
            parts.append("#\(transaction)")
        }
        
        if let total = formattedTotal {
            parts.append(total)
        }
        
        return parts.isEmpty ? "Receipt" : parts.joined(separator: " • ")
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        barcodeValue: String? = nil,
        storeName: String? = nil,
        purchaseDate: Date? = nil,
        totalAmount: Double? = nil,
        rawText: String = "",
        imageID: UUID? = nil,
        cashierNumber: String? = nil,
        registerNumber: String? = nil,
        transactionNumber: String? = nil,
        memberID: String? = nil,
        expectedItemCount: Int? = nil,
        lineItems: [LineItem] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.barcodeValue = barcodeValue
        self.storeName = storeName
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.rawText = rawText
        self.imageID = imageID
        self.cashierNumber = cashierNumber
        self.registerNumber = registerNumber
        self.transactionNumber = transactionNumber
        self.memberID = memberID
        self.expectedItemCount = expectedItemCount
        self.lineItems = lineItems
    }
    
    // MARK: - Methods
    
    /// Create a copy with updated values
    func with(
        barcodeValue: String? = nil,
        storeName: String? = nil,
        purchaseDate: Date? = nil,
        totalAmount: Double? = nil,
        rawText: String? = nil,
        imageID: UUID? = nil,
        cashierNumber: String? = nil,
        registerNumber: String? = nil,
        transactionNumber: String? = nil,
        memberID: String? = nil,
        expectedItemCount: Int? = nil,
        lineItems: [LineItem]? = nil
    ) -> Receipt {
        Receipt(
            id: self.id,
            timestamp: self.timestamp,
            barcodeValue: barcodeValue ?? self.barcodeValue,
            storeName: storeName ?? self.storeName,
            purchaseDate: purchaseDate ?? self.purchaseDate,
            totalAmount: totalAmount ?? self.totalAmount,
            rawText: rawText ?? self.rawText,
            imageID: imageID ?? self.imageID,
            cashierNumber: cashierNumber ?? self.cashierNumber,
            registerNumber: registerNumber ?? self.registerNumber,
            transactionNumber: transactionNumber ?? self.transactionNumber,
            memberID: memberID ?? self.memberID,
            expectedItemCount: expectedItemCount ?? self.expectedItemCount,
            lineItems: lineItems ?? self.lineItems
        )
    }
}

// MARK: - Validation

extension Receipt {
    /// Validation errors
    enum ValidationError: LocalizedError {
        case missingBarcode
        case missingTotal
        case invalidTotal
        case missingTransactionInfo
        
        var errorDescription: String? {
            switch self {
            case .missingBarcode:
                return "Receipt is missing barcode"
            case .missingTotal:
                return "Receipt is missing total amount"
            case .invalidTotal:
                return "Receipt has invalid total amount"
            case .missingTransactionInfo:
                return "Receipt is missing transaction information"
            }
        }
    }
    
    /// Validate receipt has minimum required information
    func validate() throws {
        // Check barcode
        guard hasBarcode else {
            throw ValidationError.missingBarcode
        }
        
        // Check total
        guard hasTotal else {
            throw ValidationError.missingTotal
        }
        
        if let total = totalAmount, total <= 0 {
            throw ValidationError.invalidTotal
        }
        
        // Check transaction info
        if registerNumber == nil && transactionNumber == nil {
            throw ValidationError.missingTransactionInfo
        }
    }
    
    /// Check if receipt is complete (has all recommended fields)
    var isComplete: Bool {
        hasBarcode &&
        hasTotal &&
        registerNumber != nil &&
        transactionNumber != nil &&
        cashierNumber != nil
    }
    
    /// Completion percentage (0.0 - 1.0)
    var completionPercentage: Double {
        var score = 0.0
        let totalFields = 7.0
        
        if hasBarcode { score += 1 }
        if hasTotal { score += 1 }
        if registerNumber != nil { score += 1 }
        if transactionNumber != nil { score += 1 }
        if cashierNumber != nil { score += 1 }
        if memberID != nil { score += 1 }
        if !lineItems.isEmpty { score += 1 }
        
        return score / totalFields
    }
}

// MARK: - Sample Data (for previews and testing)

extension Receipt {
    static let sample = Receipt(
        barcodeValue: "123456789012",
        storeName: "COSTCO",
        purchaseDate: Date(),
        totalAmount: 125.47,
        rawText: "Sample receipt text",
        cashierNumber: "042",
        registerNumber: "12",
        transactionNumber: "0056",
        memberID: "111234567890",
        expectedItemCount: 8,
        lineItems: [
            LineItem.sample,
            LineItem(itemNumber: 987654, description: "Organic Bananas", quantity: 3, price: 4.99),
            LineItem(itemNumber: 456789, description: "Rotisserie Chicken", quantity: 1, price: 4.99)
        ]
    )
    
    static let sampleWithoutBarcode = Receipt(
        storeName: "COSTCO",
        totalAmount: 75.32,
        rawText: "Receipt without barcode",
        registerNumber: "8",
        transactionNumber: "0123"
    )
    
    static let sampleIncomplete = Receipt(
        totalAmount: 50.00,
        rawText: "Incomplete receipt"
    )
}

// NOTE: SwiftData entities (ReceiptEntity, AuditEntity, ImageEntity) are defined in
// Core/Infrastructure/Persistence/SwiftDataRepositories.swift
// This file should only contain the domain model Receipt struct.
