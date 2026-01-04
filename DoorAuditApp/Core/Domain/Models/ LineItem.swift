//
//  LineItem.swift
//  L1 Demo
//
//  Domain model for receipt line items
//  Created: December 2025
//

import Foundation

/// Represents a single line item on a receipt
struct LineItem: Identifiable, Hashable, Codable {
    
    // MARK: - Properties
    
    let id: UUID
    let itemNumber: Int?
    let description: String
    let quantity: Int?
    let price: Double?
    let total: Double?
    
    // MARK: - Computed Properties
    
    var formattedPrice: String? {
        guard let price = price else { return nil }
        return String(format: "$%.2f", price)
    }
    
    var formattedTotal: String? {
        guard let total = total else { return nil }
        return String(format: "$%.2f", total)
    }
    
    var hasCompleteInfo: Bool {
        itemNumber != nil && quantity != nil && price != nil
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        itemNumber: Int? = nil,
        description: String,
        quantity: Int? = nil,
        price: Double? = nil,
        total: Double? = nil
    ) {
        self.id = id
        self.itemNumber = itemNumber
        self.description = description
        self.quantity = quantity
        self.price = price
        self.total = total
    }
}

// MARK: - Sample Data

extension LineItem {
    static let sample = LineItem(
        itemNumber: 123456,
        description: "Kirkland Signature Water 40pk",
        quantity: 2,
        price: 3.99,
        total: 7.98
    )
}
