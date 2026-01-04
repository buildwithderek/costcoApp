//
//  EnhancedCSVExportService.swift
//  DoorAuditApp
//
//  Enhanced CSV export matching exact spreadsheet format
//  Includes all columns from the provided image
//  Created: December 2025
//

import Foundation
import UIKit

/// Enhanced CSV export service matching the exact format from your spreadsheet
final class EnhancedCSVExportService {
    
    // MARK: - CSV Headers (matching your spreadsheet exactly)
    
    private static let headers = [
        "date",
        "Register",
        "Ring",
        "Cashier #",
        "B.O.B",
        "3/ TOTAL (Y/N)",
        "PRESCAN Y/N",
        "PRESCAN # = BASKET # Y/N",
        "ITEM # OVERCHARGE",
        "OVERCHARGE NAME",
        "OVERCHARGE COST",
        "ITEM # UNDERCHARGE",
        "UNDERCHARGE NAME",
        "UNDERCHARGE COST",
        "Item Name",
        "QUANTITIES",
        "COST",
        "Total",
        "Security",
        "Cashier",
        "Asst.",
        "Supervisor",
        "Week"
    ]
    
    // MARK: - Date Formatters
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M/d/yyyy"  // Matches your format: 12/15/2025
        return f
    }()
    
    private static let filenameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd-yyyy_HHmmss"
        return f
    }()
    
    // MARK: - Export to CSV
    
    /// Export audits to CSV file matching the exact spreadsheet format
    static func exportAudits(
        receipts: [Receipt],
        audits: [AuditData],
        date: Date
    ) throws -> URL {
        Logger.shared.info("Starting enhanced CSV export for \(receipts.count) receipts")
        
        guard !receipts.isEmpty else {
            throw EnhancedExportError.noData
        }
        
        // Create audit lookup
        let auditLookup = Dictionary(
            uniqueKeysWithValues: audits.map { ($0.receiptID, $0) }
        )
        
        // Build CSV
        var csvLines = [String]()
        
        // Add header row
        csvLines.append(headers.joined(separator: ","))
        
        // Add data rows
        for receipt in receipts {
            let audit = auditLookup[receipt.id]
            let row = buildCSVRow(receipt: receipt, audit: audit)
            csvLines.append(row)
        }
        
        let csvText = csvLines.joined(separator: "\n") + "\n"
        
        // Generate filename
        let dateStr = filenameFormatter.string(from: date)
        let fileName = "Costco_Audit_\(dateStr).csv"
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        
        // Write to file
        try csvText.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // Verify
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw EnhancedExportError.fileWriteFailed
        }
        
        Logger.shared.success("CSV exported: \(fileName)")
        return fileURL
    }
    
    // MARK: - Build CSV Row
    
    private static func buildCSVRow(receipt: Receipt, audit: AuditData?) -> String {
        // Parse audit notes for structured data
        let auditInfo = parseAuditNotes(audit?.notes)
        
        // Date (receipt date or timestamp)
        let date = dateFormatter.string(from: receipt.purchaseDate ?? receipt.timestamp)
        
        // Register & Transaction
        let register = receipt.registerNumber ?? ""
        let ring = receipt.transactionNumber ?? ""
        let cashierNumber = receipt.cashierNumber ?? ""
        
        // Audit Checks (Y/N format)
        let bob = auditInfo.bob ? "Y" : "N"
        let threeTotal = auditInfo.threeTotal ? "Y" : "N"
        let prescan = auditInfo.prescan ? "Y" : "N"
        let prescanMatch = auditInfo.prescanMatch ? "Y" : "N"
        
        // Issues - parse from audit issues
        var overchargeNum = ""
        var overchargeName = ""
        var overchargeCost = ""
        var underchargeNum = ""
        var underchargeName = ""
        var underchargeCost = ""
        
        // Parse issue1 (overcharge)
        if let issue1 = audit?.issue1 {
            let parts = parseIssue(issue1)
            overchargeNum = parts.number
            overchargeName = parts.name
            overchargeCost = parts.cost
        }
        
        // Parse issue2 (undercharge)
        if let issue2 = audit?.issue2 {
            let parts = parseIssue(issue2)
            underchargeNum = parts.number
            underchargeName = parts.name
            underchargeCost = parts.cost
        }
        
        // Line Items - combine all items
        let itemNames = receipt.lineItems.map { $0.description }.joined(separator: "; ")
        let quantities = receipt.lineItems.map { 
            String($0.quantity ?? 1)
        }.joined(separator: "; ")
        
        let costs = receipt.lineItems.compactMap { 
            $0.price.map { String(format: "%.2f", $0) }
        }.joined(separator: "; ")
        
        // Total
        let total = receipt.totalAmount.map { String(format: "%.2f", $0) } ?? ""
        
        // Staff
        let security = audit?.staffName ?? ""
        let cashier = auditInfo.cashier
        let assistant = auditInfo.assistant
        let supervisor = audit?.auditorName ?? auditInfo.supervisor
        let week = auditInfo.week
        
        // Build row - escape all fields
        let fields = [
            date,
            register,
            ring,
            cashierNumber,
            bob,
            threeTotal,
            prescan,
            prescanMatch,
            overchargeNum,
            overchargeName,
            overchargeCost,
            underchargeNum,
            underchargeName,
            underchargeCost,
            itemNames,
            quantities,
            costs,
            total,
            security,
            cashier,
            assistant,
            supervisor,
            week
        ]
        
        return fields.map { escapeCSV($0) }.joined(separator: ",")
    }
    
    // MARK: - Parse Helpers
    
    private static func parseIssue(_ issue: String) -> (number: String, name: String, cost: String) {
        // Parse format: "OVERCHARGE - #12345 - Item Name - $5.99"
        let parts = issue.split(separator: "-").map { 
            $0.trimmingCharacters(in: .whitespaces) 
        }
        
        var number = ""
        var name = ""
        var cost = ""
        
        for (index, part) in parts.enumerated() {
            if part.starts(with: "#") {
                number = String(part.dropFirst())
            } else if part.starts(with: "$") {
                cost = String(part.dropFirst())
            } else if index > 0 && !part.uppercased().contains("OVERCHARGE") && !part.uppercased().contains("UNDERCHARGE") {
                if name.isEmpty {
                    name = part
                }
            }
        }
        
        return (number, name, cost)
    }
    
    private static func parseAuditNotes(_ notes: String?) -> AuditInfo {
        guard let notes = notes else {
            return AuditInfo()
        }
        
        var info = AuditInfo()
        
        // Parse notes format: "BOB: Y | 3/TOTAL: Y | Cashier: SCO | Week: Week 4"
        let parts = notes.split(separator: "|").map { 
            $0.trimmingCharacters(in: .whitespaces) 
        }
        
        for part in parts {
            let keyValue = part.split(separator: ":").map { 
                $0.trimmingCharacters(in: .whitespaces) 
            }
            
            guard keyValue.count == 2 else { continue }
            
            let key = keyValue[0].uppercased()
            let value = keyValue[1]
            
            switch key {
            case "BOB":
                info.bob = value.uppercased() == "Y"
            case "3/TOTAL":
                info.threeTotal = value.uppercased() == "Y"
            case "PRESCAN":
                info.prescan = value.uppercased() == "Y"
            case "PRESCAN MATCH":
                info.prescanMatch = value.uppercased() == "Y"
            case "CASHIER":
                info.cashier = value
            case "ASST":
                info.assistant = value
            case "SUP", "SUPERVISOR":
                info.supervisor = value
            case "WEEK":
                info.week = value
            default:
                break
            }
        }
        
        return info
    }
    
    // MARK: - CSV Escaping
    
    private static func escapeCSV(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If contains special characters, wrap in quotes
        if trimmed.contains(",") || trimmed.contains("\"") || trimmed.contains("\n") {
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        
        return trimmed
    }
}

// MARK: - Supporting Types

private struct AuditInfo {
    var bob = false
    var threeTotal = false
    var prescan = false
    var prescanMatch = false
    var cashier = ""
    var assistant = ""
    var supervisor = ""
    var week = ""
}

// MARK: - Errors

enum EnhancedExportError: LocalizedError {
    case noData
    case fileWriteFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No audit data to export"
        case .fileWriteFailed:
            return "Failed to write CSV file"
        case .invalidData:
            return "Invalid data format"
        }
    }
}
