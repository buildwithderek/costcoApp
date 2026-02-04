//
//  VisionOCRService.swift
//  L1 Demo
//
//  OCR Service using Apple's Vision framework
//  ENHANCED: Handles columnar receipt format where items and prices are on separate lines
//  FIXED: Scans entire receipt for prices (they appear after SUBTOTAL in OCR output)
//  ADDED: Item count validation with mismatch warnings
//  Created: December 2025
//

import UIKit
import Vision

/// Implementation of OCRService using Apple's Vision framework
final class VisionOCRService: OCRService {
    
    // MARK: - OCR Service Protocol Implementation
    
    func extractText(from image: UIImage) async throws -> String {
        Logger.shared.info("Starting OCR text extraction...")
        
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        request.recognitionLanguages = ["en-US"]
        
        let handler = VNImageRequestHandler(cgImage: cgImage)
        try handler.perform([request])
        
        let text = request.results?
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n") ?? ""
        
        guard !text.isEmpty else {
            throw OCRError.noTextFound
        }
        
        Logger.shared.success("OCR extracted \(text.count) characters")
        return text
    }
    
    func parseReceiptData(from text: String) -> ParsedReceiptData {
        Logger.shared.info("📝 parseReceiptData: Starting to parse receipt text...")
        
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Log the raw OCR text for debugging
        Logger.shared.debug("📝 Total lines from OCR: \(lines.count)")
        for (index, line) in lines.enumerated() {
            Logger.shared.debug("📝 Line[\(index)]: \(line)")
        }
        
        var storeName: String?
        var date: Date?
        var total: Double?
        var cashierNumber: String?
        var registerNumber: String?
        var transactionNumber: String?
        var memberID: String?
        var expectedItemCount: Int?
        var allAmounts: [Double] = []
        
        // MARK: Metadata pass
        for (index, line) in lines.enumerated() {
            let lower = line.lowercased()
            
            // Store name (first few lines)
            if storeName == nil && index < 5 {
                if lower.contains("costco") || lower.contains("wholesale") {
                    storeName = "Costco"
                }
            }
            
            // Date - look for MM/DD/YYYY pattern
            if date == nil {
                date = extractDate(from: line)
            }
            
            // Item count - "Items Sold: 9" or "TOTAL NUMBER OF ITEMS SOLD = 9"
            if let count = extractItemCount(from: line) {
                expectedItemCount = count
                Logger.shared.info("📝 Found expected item count: \(count)")
            }
            
            // Transaction details from footer line: "Whse:424 Trm: 10 Trn:375 OP:114"
            if let footer = extractFooterInfo(from: line) {
                registerNumber = footer.terminal
                transactionNumber = footer.transaction
                cashierNumber = footer.cashier
                Logger.shared.info("📝 Found footer: Trm=\(footer.terminal), Trn=\(footer.transaction), OP=\(footer.cashier)")
            }
            
            // Member ID: "2D Member 112038017578"
            if memberID == nil {
                memberID = extractMember(from: line)
            }
            
            // Extract all amounts for total detection
            let amounts = extractAmounts(from: line)
            allAmounts.append(contentsOf: amounts)
            
            // Total - look for "TOTAL" keyword
            if lower.contains("total") && !lower.contains("items") && !lower.contains("number") {
                if let maxAmount = amounts.max() {
                    total = maxAmount
                }
            }
        }
        
        // MARK: Extract line items using columnar format detection
        Logger.shared.info("📝 Starting COLUMNAR item extraction...")
        let lineItems = extractColumnarItems(from: lines)
        Logger.shared.info("📝 Extracted \(lineItems.count) items")
        
        // MARK: Validate item count
        if let expected = expectedItemCount {
            let extracted = lineItems.count
            let difference = abs(expected - extracted)
            
            if extracted == expected {
                Logger.shared.success("[OCR] Item count matches: \(extracted) items")
            } else if difference <= 2 {
                // Small difference - may be CA REDEMP items or OCR noise
                Logger.shared.warning("[OCR] Item count mismatch: extracted \(extracted), expected \(expected) (difference: \(difference))")
            } else {
                // Large difference - significant issue
                Logger.shared.error("[OCR] SIGNIFICANT item count mismatch: extracted \(extracted), expected \(expected) (difference: \(difference))")
                Logger.shared.warning("[OCR] Consider rescanning receipt for better accuracy")
            }
        }
        
        // If no total found, use max amount from allAmounts
        if total == nil {
            total = allAmounts.max()
        }
        
        Logger.shared.info("📝 Parsed: store=\(storeName ?? "nil"), items=\(lineItems.count), total=\(total?.description ?? "nil")")
        
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
    
    // MARK: - Columnar Item Extraction
    // Handles receipts where item names and prices are on separate lines
    // The OCR reads left column (items) then right column (prices) separately
    
    private func extractColumnarItems(from lines: [String]) -> [LineItem] {
        var itemCandidates: [(code: String?, name: String, lineIndex: Int)] = []
        var priceCandidates: [(price: Double, lineIndex: Int)] = []
        
        let lower = lines.map { $0.lowercased() }
        
        // Find where items START (after "Member" line)
        var itemStartIndex = 0
        for (i, line) in lower.enumerated() {
            if line.contains("member") && lines[i].contains(where: { $0.isNumber }) {
                itemStartIndex = i + 1
                break
            }
        }
        
        // Find where items END (at "SUBTOTAL" line)
        var itemEndIndex = lines.count
        for (i, line) in lower.enumerated() where i > itemStartIndex {
            if line.contains("subtotal") {
                itemEndIndex = i
                break
            }
        }
        
        Logger.shared.debug("📝 Item names section: lines[\(itemStartIndex)..<\(itemEndIndex)]")
        
        // PASS 1: Extract item names from the items section
        for i in itemStartIndex..<itemEndIndex {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            let lineLower = line.lowercased()
            
            // Skip known non-item patterns
            if line.count < 3 {
                Logger.shared.debug("📝 [\(i)] Skipped (too short): '\(line)'")
                continue
            }
            if skipKeywords.contains(where: { lineLower.contains($0) }) {
                Logger.shared.debug("📝 [\(i)] Skipped (keyword): '\(line)'")
                continue
            }
            
            // Check if this is an item line (code + name)
            if let item = extractItemCandidate(from: line) {
                // Skip CA REDEMP items
                if item.name.lowercased().contains("redemp") || item.name.lowercased().contains("crv") {
                    Logger.shared.debug("📝 [\(i)] Skipped REDEMP: \(item.name)")
                    continue
                }
                itemCandidates.append((code: item.code, name: item.name, lineIndex: i))
                Logger.shared.debug("📝 [\(i)] Item candidate: \(item.code ?? "?") \(item.name)")
            } else {
                Logger.shared.debug("📝 [\(i)] No match: '\(line)'")
            }
        }
        
        // PASS 2: Extract ALL standalone prices from the ENTIRE receipt
        // Prices appear AFTER the item section in columnar OCR output
        for i in 0..<lines.count {
            let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
            
            // Check if this line is JUST a price (standalone price line)
            if let price = extractStandalonePrice(from: line) {
                priceCandidates.append((price: price, lineIndex: i))
                Logger.shared.debug("📝 [\(i)] Price candidate: $\(price)")
            }
        }
        
        Logger.shared.info("📝 Found \(itemCandidates.count) item candidates and \(priceCandidates.count) price candidates")
        
        // PASS 3: Correlate items with prices
        // Strategy: The first N prices correspond to the first N items (in order)
        var results: [LineItem] = []
        
        let itemCount = itemCandidates.count
        for i in 0..<itemCount {
            let item = itemCandidates[i]
            
            // Get corresponding price if available
            let price: Double? = (i < priceCandidates.count) ? priceCandidates[i].price : nil
            
            let lineItem = LineItem(
                itemNumber: item.code.flatMap { Int($0) },
                description: item.name,
                quantity: 1,
                price: price,
                total: price
            )
            results.append(lineItem)
            
            if let p = price {
                Logger.shared.info("📝 ✅ MATCHED: '\(item.name)' @ $\(p)")
            } else {
                Logger.shared.warning("📝 ⚠️ Item without price: '\(item.name)'")
            }
        }
        
        return results
    }
    
    /// Extract a standalone price from a line (just a number like "19.89")
    private func extractStandalonePrice(from line: String) -> Double? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Must be a simple price format: optional minus, digits, dot, 2 digits
        let pricePattern = try! NSRegularExpression(
            pattern: "^-?\\$?([0-9]+\\.[0-9]{2})$",
            options: []
        )
        
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        guard let match = pricePattern.firstMatch(in: trimmed, range: range),
              let priceRange = Range(match.range(at: 1), in: trimmed),
              let price = Double(trimmed[priceRange]) else {
            return nil
        }
        
        // Filter out unlikely prices
        // - Too high for a single item (probably a total)
        // - Too low (probably tax or change)
        // - Round numbers like 100.00, 87.90 are likely totals
        if price > 100 {
            return nil  // Likely a total or cash amount
        }
        if price < 0.10 {
            return nil  // Likely tax rate or small fee
        }
        
        return price
    }
    
    /// Extract an item candidate (code + name) from a line
    private func extractItemCandidate(from line: String) -> (code: String?, name: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        
        // Skip if too short
        if trimmed.count < 4 { return nil }
        
        // Skip if mostly digits (likely a transaction ID or barcode)
        let digits = trimmed.filter { $0.isNumber }
        let letters = trimmed.filter { $0.isLetter }
        if digits.count >= 10 && letters.count <= 2 { return nil }
        
        // Skip lines that are just "E" or "E:" (OCR artifacts from tax indicators)
        if trimmed == "E" || trimmed == "E:" || trimmed == "-•" { return nil }
        
        // Pattern 1: "841930 THAI JASMINE" (code + name)
        // Pattern 2: "E 841930 THAI JASMINE" (E prefix + code + name)
        // Pattern 3: "591 APPLE JUICE" (3-digit code + name)
        // Pattern 4: "1 2% MILK" (quantity + name, but we'll treat "1" as noise)
        
        // Try: Optional E/A prefix + 3-7 digit code + name
        // Changed from {4,7} to {3,7} to catch items like "591 APPLE JUICE"
        let itemPattern = try! NSRegularExpression(
            pattern: "^[EA]?\\s*([0-9]{3,7})\\s+(.+)$",
            options: [.caseInsensitive]
        )
        
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        if let match = itemPattern.firstMatch(in: trimmed, range: range),
           let codeRange = Range(match.range(at: 1), in: trimmed),
           let nameRange = Range(match.range(at: 2), in: trimmed) {
            
            let code = String(trimmed[codeRange])
            var name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
            
            // Remove trailing price if present (shouldn't be for columnar, but just in case)
            name = removeTrailingPrice(from: name)
            
            // Validate name has at least 2 letters
            let nameLetters = name.filter { $0.isLetter }
            if nameLetters.count >= 2 {
                return (code: code, name: name.uppercased())
            }
        }
        
        // Special case: "1 2% MILK" - starts with digit but is really an item
        // This happens when OCR misreads "E 12345" as "1 2345"
        let milkPattern = try! NSRegularExpression(
            pattern: "^\\d\\s+(.+)$",
            options: [.caseInsensitive]
        )
        if let match = milkPattern.firstMatch(in: trimmed, range: range),
           let nameRange = Range(match.range(at: 1), in: trimmed) {
            let name = String(trimmed[nameRange]).trimmingCharacters(in: .whitespaces)
            let nameLetters = name.filter { $0.isLetter }
            if nameLetters.count >= 2 && !skipKeywords.contains(where: { name.lowercased().contains($0) }) {
                return (code: nil, name: name.uppercased())
            }
        }
        
        return nil
    }
    
    /// Remove trailing price from item name if present
    private func removeTrailingPrice(from name: String) -> String {
        let pricePattern = try! NSRegularExpression(
            pattern: "\\s+\\d+\\.\\d{2}\\s*[A-Z]?\\s*$",
            options: [.caseInsensitive]
        )
        let range = NSRange(name.startIndex..., in: name)
        return pricePattern.stringByReplacingMatches(in: name, range: range, withTemplate: "")
    }
    
    // MARK: - Keywords to Skip
    
    private let skipKeywords: Set<String> = [
        "subtotal", "tax", "total", "change", "balance", "approved",
        "visa", "mastercard", "debit", "credit", "cash", "eft",
        "thank", "please", "come again", "welcome",
        "aid:", "seq#", "app#", "tran", "whse:", "trm:", "trn:", "op#",
        "member", "costco", "wholesale", "warehouse", "signal hill",
        "self-checkout", "self checkout", "instacart",
        "refund", "void", "return", "exchange",
        "e willow", "ca 90755", "427-2537",  // Address parts
        "redemp", "crv"  // CA redemption value
    ]
    
    // MARK: - Helper Methods
    
    private func extractAmounts(from text: String) -> [Double] {
        let moneyRegex = try! NSRegularExpression(
            pattern: "\\$?([0-9]+\\.[0-9]{2})",
            options: []
        )
        let range = NSRange(text.startIndex..., in: text)
        return moneyRegex.matches(in: text, range: range)
            .compactMap {
                Range($0.range(at: 1), in: text)
                    .flatMap { Double(text[$0]) }
            }
    }
    
    private func extractDate(from text: String) -> Date? {
        let dateRegex = try! NSRegularExpression(
            pattern: "(\\d{1,2})[/-](\\d{1,2})[/-](\\d{2,4})",
            options: []
        )
        let range = NSRange(text.startIndex..., in: text)
        guard let match = dateRegex.firstMatch(in: text, range: range),
              let matchRange = Range(match.range, in: text) else {
            return nil
        }
        
        let dateString = String(text[matchRange]).replacingOccurrences(of: "-", with: "/")
        return dateString.toDate(format: .receipt)
    }
    
    private func extractItemCount(from text: String) -> Int? {
        let patterns = [
            "Items\\s+Sold:?\\s*(\\d+)",
            "TOTAL\\s+NUMBER\\s+OF\\s+ITEMS\\s+SOLD\\s*[-=:]?\\s*(\\d+)"
        ]
        
        for pattern in patterns {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(text.startIndex..., in: text)
            if let match = regex.firstMatch(in: text, range: range) {
                for i in 1..<match.numberOfRanges {
                    if let r = Range(match.range(at: i), in: text),
                       let count = Int(text[r]) {
                        return count
                    }
                }
            }
        }
        return nil
    }
    
    private func extractMember(from text: String) -> String? {
        let memberRegex = try! NSRegularExpression(
            pattern: "(?:2D\\s+)?Member\\s+(\\d{10,15})",
            options: [.caseInsensitive]
        )
        let range = NSRange(text.startIndex..., in: text)
        guard let match = memberRegex.firstMatch(in: text, range: range),
              let r = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[r])
    }
    
    private func extractFooterInfo(from line: String) -> (warehouse: String, terminal: String, transaction: String, cashier: String)? {
        // Pattern: "Whse:424 Trm: 10 Trn:375 OP:114"
        let footerRegex = try! NSRegularExpression(
            pattern: "Whse:?\\s*(\\d+)\\s+Trm:?\\s*(\\d+)\\s+Trn:?\\s*(\\d+)\\s+OP:?\\s*(\\d+)",
            options: [.caseInsensitive]
        )
        let range = NSRange(line.startIndex..., in: line)
        guard let match = footerRegex.firstMatch(in: line, range: range),
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
}

// MARK: - OCR Errors

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case processingFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image for OCR"
        case .noTextFound:
            return "No text found in image"
        case .processingFailed(let error):
            return "OCR processing failed: \(error.localizedDescription)"
        }
    }
}
