//
//  CostcoReceiptParser.swift
//  DoorAuditApp
//
//  Costco-specific receipt parsing service
//  IMPROVED: More flexible patterns and better logging
//
//  Location: Core/Infrastructure/Services/CostcoReceiptParser.swift
//
//  Created: December 2025
//

import Foundation

// MARK: - Receipt Parser Protocol

/// Protocol for store-specific receipt parsing
/// Allows easy addition of other stores (Target, Walmart, etc.)
protocol ReceiptParser {
    /// Parse raw OCR text into structured receipt data
    func parse(_ text: String) -> ParsedReceiptData
    
    /// Check if this parser can handle the given text
    func canParse(_ text: String) -> Bool
}

// MARK: - Costco Receipt Parser

/// Costco-specific receipt parser
/// Handles Signal Hill #424 format and general Costco receipts
final class CostcoReceiptParser: ReceiptParser {
    
    // MARK: - Singleton (optional, can also use DI)
    
    static let shared = CostcoReceiptParser()
    
    // MARK: - Protocol Methods
    
    func canParse(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("costco") || lower.contains("wholesale")
    }
    
    func parse(_ text: String) -> ParsedReceiptData {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        Logger.shared.debug("CostcoReceiptParser: Processing \(lines.count) lines")
        
        // Debug: print all lines
        for (i, line) in lines.enumerated() {
            Logger.shared.debug("Line \(i): '\(line)'")
        }
        
        var storeName: String? = "Costco"
        var date: Date?
        var total: Double?
        var cashierNumber: String?
        var registerNumber: String?
        var transactionNumber: String?
        var memberID: String?
        var expectedItemCount: Int?
        var allAmounts: [Double] = []
        
        // MARK: Pass 1 - Metadata extraction
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            
            // Store name confirmation
            if index < 5 && (lower.contains("costco") || lower.contains("wholesale")) {
                storeName = "Costco"
            }
            
            // Date
            if date == nil {
                date = extractDate(from: line)
            }
            
            // Item count: "TOTAL NUMBER OF ITEMS SOLD = 12" or "Items Sold: 12"
            if let count = extractItemCount(from: line) {
                expectedItemCount = count
                Logger.shared.debug("Found expected item count: \(count) in line: '\(line)'")
            }
            
            // Footer line: "Whse:424 Trm:2 Trn:128 OP:357"
            if let footer = extractFooterInfo(from: line) {
                registerNumber = footer.terminal
                transactionNumber = footer.transaction
                cashierNumber = footer.cashier
                Logger.shared.debug("Found footer: Reg=\(footer.terminal), Trn=\(footer.transaction), OP=\(footer.cashier)")
            }
            
            // Individual field fallbacks
            if cashierNumber == nil {
                cashierNumber = extractField(pattern: Patterns.cashier, from: line)
            }
            if registerNumber == nil {
                registerNumber = extractField(pattern: Patterns.terminal, from: line)
            }
            if transactionNumber == nil {
                transactionNumber = extractField(pattern: Patterns.transaction, from: line)
            }
            
            // Member ID: "FU Member 111970946598"
            if memberID == nil {
                memberID = extractField(pattern: Patterns.member, from: line)
            }
            
            // Amounts for total detection
            let amounts = extractAmounts(from: line)
            allAmounts.append(contentsOf: amounts)
            
            // Total
            if Keywords.total.contains(where: { lower.contains($0) }) && !lower.contains("items") {
                total = amounts.max()
                if let t = total {
                    Logger.shared.debug("Found total: $\(t) in line: '\(line)'")
                }
            }
        }
        
        // MARK: Pass 2 - Item extraction
        let lineItems = extractItems(from: lines)
        
        // Fallback total
        if total == nil {
            total = allAmounts.max()
        }
        
        Logger.shared.info("CostcoReceiptParser result: \(lineItems.count) items, expected: \(expectedItemCount ?? 0), total: $\(total ?? 0)")
        
        return ParsedReceiptData(
            storeName: storeName,
            date: date,
            total: total,
            cashierNumber: cashierNumber,
            registerNumber: registerNumber,
            transactionNumber: transactionNumber,
            memberID: memberID,
            expectedItemCount: expectedItemCount,
            lineItems: lineItems
        )
    }
    
    // MARK: - Item Extraction
    
    private func extractItems(from lines: [String]) -> [LineItem] {
        var results: [LineItem] = []
        var pendingQuantity: (qty: Int, unitPrice: Double)?
        var discounts: [String: Double] = [:]
        
        // Find item section
        let (start, end) = findItemSection(in: lines)
        let itemLines = Array(lines[start..<end])
        
        Logger.shared.debug("Item section: lines \(start) to \(end) (\(itemLines.count) lines)")
        
        // First pass: collect discounts (e.g., "/1575171 4.00-")
        for line in itemLines {
            if let (itemCode, amount) = matchDiscount(line) {
                discounts[itemCode] = amount
            }
        }
        
        // Second pass: extract items
        for (index, line) in itemLines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Skip non-items
            if isNonItemLine(trimmed) {
                Logger.shared.debug("Skipping non-item [\(index)]: '\(trimmed)'")
                continue
            }
            if matchDiscount(trimmed) != nil {
                Logger.shared.debug("Skipping discount [\(index)]: '\(trimmed)'")
                continue
            }
            
            // Quantity line: "2 @ 24.49"
            if let qty = matchQuantityLine(trimmed) {
                pendingQuantity = qty
                Logger.shared.debug("Found quantity [\(index)]: \(qty.qty) @ $\(qty.unitPrice)")
                continue
            }
            
            // Try item patterns
            if var item = matchItemLine(trimmed) {
                // Skip CA redemption values
                if Keywords.skipItems.contains(where: { item.description.lowercased().contains($0) }) {
                    Logger.shared.debug("Skipping redemption item [\(index)]: '\(trimmed)'")
                    continue
                }
                
                // Apply pending quantity
                if let pending = pendingQuantity {
                    item = LineItem(
                        itemNumber: item.itemNumber,
                        description: item.description,
                        quantity: pending.qty,
                        price: pending.unitPrice,
                        total: item.total
                    )
                    pendingQuantity = nil
                }
                
                Logger.shared.debug("✓ Matched item [\(index)]: #\(item.itemNumber ?? 0) '\(item.description)' $\(item.price ?? 0)")
                results.append(item)
            } else {
                Logger.shared.debug("✗ No match [\(index)]: '\(trimmed)'")
            }
        }
        
        Logger.shared.info("Extracted \(results.count) line items")
        return results
    }
    
    // MARK: - Pattern Matching
    
    private func matchItemLine(_ line: String) -> LineItem? {
        // Try E prefix (taxable): "E 1555132 TANGERINE JU 9.39"
        if let match = Patterns.eItem.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            Logger.shared.debug("  -> E-item pattern matched")
            return extractLineItem(from: line, match: match)
        }
        
        // Try A prefix (age-restricted): "A 123456 WINE 19.99"
        if let match = Patterns.aItem.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            Logger.shared.debug("  -> A-item pattern matched")
            return extractLineItem(from: line, match: match)
        }
        
        // Try standard (no prefix): "1899650 DRFM SLIPPER 14.99 A"
        if let match = Patterns.standardItem.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            Logger.shared.debug("  -> Standard pattern matched")
            return extractLineItem(from: line, match: match)
        }
        
        // Try flexible pattern (more lenient)
        if let match = Patterns.flexibleItem.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            Logger.shared.debug("  -> Flexible pattern matched")
            return extractLineItem(from: line, match: match)
        }
        
        // Try simple pattern (just name and price)
        if let match = Patterns.simpleItem.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)) {
            Logger.shared.debug("  -> Simple pattern matched")
            return extractSimpleLineItem(from: line, match: match)
        }
        
        return nil
    }
    
    private func extractLineItem(from line: String, match: NSTextCheckingResult) -> LineItem? {
        guard match.numberOfRanges >= 4,
              let codeRange = Range(match.range(at: 1), in: line),
              let nameRange = Range(match.range(at: 2), in: line),
              let priceRange = Range(match.range(at: 3), in: line),
              let price = Double(line[priceRange]) else {
            return nil
        }
        
        let code = String(line[codeRange])
        let name = String(line[nameRange])
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
        
        // Validate name has at least 2 letters
        let nameLetters = name.filter { $0.isLetter }
        if nameLetters.count < 2 {
            Logger.shared.debug("  -> Rejected: name has < 2 letters: '\(name)'")
            return nil
        }
        
        return LineItem(
            itemNumber: Int(code),
            description: name,
            quantity: 1,
            price: price,
            total: price
        )
    }
    
    private func extractSimpleLineItem(from line: String, match: NSTextCheckingResult) -> LineItem? {
        guard match.numberOfRanges >= 3,
              let nameRange = Range(match.range(at: 1), in: line),
              let priceRange = Range(match.range(at: 2), in: line),
              let price = Double(line[priceRange]) else {
            return nil
        }
        
        let name = String(line[nameRange])
            .trimmingCharacters(in: .whitespaces)
            .uppercased()
        
        // Validate name has at least 2 letters
        let nameLetters = name.filter { $0.isLetter }
        if nameLetters.count < 2 {
            return nil
        }
        
        return LineItem(
            itemNumber: nil,
            description: name,
            quantity: 1,
            price: price,
            total: price
        )
    }
    
    private func matchDiscount(_ line: String) -> (itemCode: String, amount: Double)? {
        guard let match = Patterns.discount.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 3,
              let codeRange = Range(match.range(at: 1), in: line),
              let amountRange = Range(match.range(at: 2), in: line),
              let amount = Double(line[amountRange]) else {
            return nil
        }
        return (String(line[codeRange]), amount)
    }
    
    private func matchQuantityLine(_ line: String) -> (qty: Int, unitPrice: Double)? {
        guard let match = Patterns.quantity.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 3,
              let qtyRange = Range(match.range(at: 1), in: line),
              let priceRange = Range(match.range(at: 2), in: line),
              let qty = Int(line[qtyRange]),
              let price = Double(line[priceRange]) else {
            return nil
        }
        return (qty, price)
    }
    
    // MARK: - Section Detection
    
    private func findItemSection(in lines: [String]) -> (start: Int, end: Int) {
        let lower = lines.map { $0.lowercased() }
        
        // Start: after "Member" line or after store header
        var start = 0
        for (i, line) in lower.enumerated() {
            if line.contains("member") && line.contains(where: { $0.isNumber }) {
                start = min(i + 1, lines.count)
                Logger.shared.debug("Item section starts after 'Member' line at \(i)")
                break
            }
            // Also check for E/A prefix items starting (common Costco format)
            if i > 2 && (line.hasPrefix("e ") || line.hasPrefix("a ") || line.first?.isNumber == true) {
                // Check if this looks like an item line
                if Patterns.flexibleItem.firstMatch(in: lines[i], range: NSRange(lines[i].startIndex..., in: lines[i])) != nil {
                    start = i
                    Logger.shared.debug("Item section starts at first item line \(i)")
                    break
                }
            }
        }
        
        // End: before "Subtotal" or "Total"
        var end = lines.count
        for (i, line) in lower.enumerated() where i > start {
            if line.contains("subtotal") ||
               (line.contains("total") && !line.contains("items") && !line.contains("number")) {
                end = i
                Logger.shared.debug("Item section ends before 'Total/Subtotal' line at \(i)")
                break
            }
        }
        
        return (start, end)
    }
    
    private func isNonItemLine(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.count < 3 { return true }
        
        let lower = trimmed.lowercased()
        if Keywords.nonItem.contains(where: { lower.contains($0) }) { return true }
        
        // Pure numbers
        let letters = trimmed.filter { $0.isLetter }
        if letters.isEmpty { return true }
        
        // Long numbers with few letters (transaction IDs, barcodes)
        let digits = trimmed.filter { $0.isNumber }
        if digits.count >= 10 && letters.count <= 2 { return true }
        
        return false
    }
    
    // MARK: - Field Extraction
    
    private func extractFooterInfo(from line: String) -> (warehouse: String, terminal: String, transaction: String, cashier: String)? {
        guard let match = Patterns.footer.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              match.numberOfRanges >= 5,
              let whseRange = Range(match.range(at: 1), in: line),
              let trmRange = Range(match.range(at: 2), in: line),
              let trnRange = Range(match.range(at: 3), in: line),
              let opRange = Range(match.range(at: 4), in: line) else {
            return nil
        }
        
        return (
            String(line[whseRange]),
            String(line[trmRange]),
            String(line[trnRange]),
            String(line[opRange])
        )
    }
    
    private func extractField(pattern: NSRegularExpression, from line: String) -> String? {
        guard let match = pattern.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
              let range = Range(match.range(at: 1), in: line) else {
            return nil
        }
        return String(line[range])
    }
    
    private func extractAmounts(from text: String) -> [Double] {
        Patterns.money.matches(in: text, range: NSRange(text.startIndex..., in: text))
            .compactMap { match in
                guard let range = Range(match.range(at: 1), in: text) else { return nil }
                return Double(text[range])
            }
    }
    
    private func extractDate(from text: String) -> Date? {
        guard let match = Patterns.date.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        
        let dateStr = String(text[range]).replacingOccurrences(of: "-", with: "/")
        let components = dateStr.split(separator: "/")
        
        guard components.count == 3 else { return nil }
        
        var yearStr = String(components[2])
        if yearStr.count == 2 {
            yearStr = "20" + yearStr
        }
        
        let normalizedDate = "\(components[0])/\(components[1])/\(yearStr)"
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.date(from: normalizedDate)
    }
    
    private func extractItemCount(from text: String) -> Int? {
        guard let match = Patterns.itemCount.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else {
            return nil
        }
        
        for i in 1..<match.numberOfRanges {
            if let range = Range(match.range(at: i), in: text),
               let count = Int(text[range]) {
                return count
            }
        }
        return nil
    }
}

// MARK: - Patterns

private enum Patterns {
    // Money: $5.99 or 5.99
    static let money = try! NSRegularExpression(
        pattern: "-?\\$?([0-9]+\\.[0-9]{2})",
        options: []
    )
    
    // Date: MM/DD/YYYY
    static let date = try! NSRegularExpression(
        pattern: "(\\d{1,2})[/-](\\d{1,2})[/-](\\d{2,4})",
        options: []
    )
    
    // E prefix item: "E 1555132 TANGERINE JU 9.39"
    // More flexible - allows mixed case and special chars in name
    static let eItem = try! NSRegularExpression(
        pattern: "^E\\s*([0-9A-Z]{4,12})\\s+(.+?)\\s+(\\d+\\.\\d{2})\\s*(-?[A-Z])?\\s*$",
        options: [.caseInsensitive]
    )
    
    // A prefix item: "A 123456 WINE 19.99"
    static let aItem = try! NSRegularExpression(
        pattern: "^A\\s*([0-9A-Z]{4,12})\\s+(.+?)\\s+(\\d+\\.\\d{2})\\s*$",
        options: [.caseInsensitive]
    )
    
    // Standard item: "1899650 DRFM SLIPPER 14.99 A"
    // More flexible name pattern - allows any characters
    static let standardItem = try! NSRegularExpression(
        pattern: "^\\s*([0-9]{4,12})\\s+(.{2,35})\\s+(\\d+\\.\\d{2})\\s*(-?[A-Z])?\\s*$",
        options: [.caseInsensitive]
    )
    
    // Flexible item: captures item number anywhere and price at end
    // "E 1234567 SOME ITEM NAME 12.34"
    // "1234567 ITEM 12.34 A"
    static let flexibleItem = try! NSRegularExpression(
        pattern: "^[EA]?\\s*([0-9]{5,12})\\s+(.+?)\\s+(\\d+\\.\\d{2})\\s*[A-Z]?\\s*$",
        options: [.caseInsensitive]
    )
    
    // Simple item: Just name and price (no item number)
    // "KIRKLAND WATER 4.99"
    static let simpleItem = try! NSRegularExpression(
        pattern: "^([A-Za-z][A-Za-z0-9\\s/&'-]{2,30})\\s+(\\d+\\.\\d{2})\\s*$",
        options: []
    )
    
    // Discount: "0000368823 /1575171 4.00-"
    static let discount = try! NSRegularExpression(
        pattern: "^[EA]?\\s*[0-9]+\\s*/\\s*([0-9]+)\\s+(\\d+\\.\\d{2})-?\\s*$",
        options: [.caseInsensitive]
    )
    
    // Quantity: "2 @ 24.49"
    static let quantity = try! NSRegularExpression(
        pattern: "^\\s*(\\d+)\\s*@\\s*\\$?(\\d+\\.\\d{2})\\s*$",
        options: [.caseInsensitive]
    )
    
    // Item count: "TOTAL NUMBER OF ITEMS SOLD = 12" or "9 Items Sold"
    static let itemCount = try! NSRegularExpression(
        pattern: "(?:TOTAL\\s*NUMBER\\s*OF\\s*ITEMS\\s*SOLD\\s*[-=:]?\\s*(\\d+)|Items?\\s*Sold:?\\s*(\\d+)|(\\d+)\\s*Items?\\s*Sold)",
        options: [.caseInsensitive]
    )
    
    // Footer: "Whse:424 Trm:2 Trn:128 OP:357"
    static let footer = try! NSRegularExpression(
        pattern: "Whse:?\\s*(\\d+)\\s+Trm:?\\s*(\\d+)\\s+Trn:?\\s*(\\d+)\\s+OP#?:?\\s*(\\d+)",
        options: [.caseInsensitive]
    )
    
    // Individual fields
    static let cashier = try! NSRegularExpression(pattern: "OP#?:?\\s*(\\d+)", options: [.caseInsensitive])
    static let terminal = try! NSRegularExpression(pattern: "Tr[mn]:?\\s*(\\d+)", options: [.caseInsensitive])
    static let transaction = try! NSRegularExpression(pattern: "Trn:?\\s*(\\d+)", options: [.caseInsensitive])
    static let member = try! NSRegularExpression(pattern: "(?:FU\\s+)?Member\\s+(\\d{10,15})", options: [.caseInsensitive])
}

// MARK: - Keywords

private enum Keywords {
    static let total: Set<String> = [
        "total", "amount due", "amt due", "grand total", "**** total"
    ]
    
    static let nonItem: Set<String> = [
        "subtotal", "tax", "change", "balance", "approved",
        "visa", "mastercard", "debit", "credit", "cash", "eft",
        "thank", "please", "come again", "welcome", "seasons greetings",
        "aid:", "seq#", "app#", "tran id", "whse:", "trm:", "trn:", "op#",
        "costco", "wholesale", "warehouse", "signal hill",
        "self-checkout", "self checkout", "instacart",
        "refund", "void", "return", "exchange",
        "verified by pin", "resp:", "instant savings", "total tax", "a 10.5"
    ]
    
    static let skipItems: Set<String> = [
        "ca redemp va", "ca redemp", "redemp va", "crv"
    ]
}
