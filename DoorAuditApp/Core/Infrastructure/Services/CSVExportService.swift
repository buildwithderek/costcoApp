//
//  CSVExportService.swift
//  L1 Demo
//
//  CSV/ZIP Export service
//  Consolidates logic from 3 export managers
//  Created: December 2025
//

import Foundation
import UIKit

/// Implementation of ExportService for CSV and ZIP formats
/// Consolidates AuditExportManager, EditableAuditExportManager, ZipExportManager
final class CSVExportService: ExportService {
    
    // MARK: - Export Service Protocol Implementation
    
    func exportCSV(
        receipts: [Receipt],
        audits: [AuditData],
        includeHeaders: Bool
    ) async throws -> URL {
        Logger.shared.info("Generating CSV export for \(receipts.count) receipts...")
        
        var csv = ""
        
        // Create audit lookup dictionary
        let auditLookup = Dictionary(
            uniqueKeysWithValues: audits.map { ($0.receiptID, $0) }
        )
        
        // Header row
        if includeHeaders {
            csv += generateCSVHeader()
        }
        
        // Data rows - one row per line item (matching spreadsheet format)
        for receipt in receipts {
            let audit = auditLookup[receipt.id]
            
            // Generate one row for each line item in the receipt
            for lineItem in receipt.lineItems {
                csv += generateCSVRow(
                    receipt: receipt,
                    lineItem: lineItem,
                    audit: audit
                )
            }
            
            // If receipt has no line items, still create one row with receipt info
            if receipt.lineItems.isEmpty {
                csv += generateCSVRow(
                    receipt: receipt,
                    lineItem: nil,
                    audit: audit
                )
            }
        }
        
        // Save to temp file
        let filename = generateFilename(date: Date(), extension: "csv")
        let fileURL = try saveToTempFile(data: csv.data(using: .utf8)!, filename: filename)
        
        Logger.shared.success("CSV exported: \(filename)")
        return fileURL
    }
    
    func exportZIP(
        receipts: [Receipt],
        audits: [AuditData],
        images: [UUID: Data]
    ) async throws -> URL {
        Logger.shared.info("Generating ZIP export with \(images.count) images...")
        
        // For now, just export CSV
        // TODO: Implement actual ZIP with images using ZipArchive library
        
        let csvURL = try await exportCSV(
            receipts: receipts,
            audits: audits,
            includeHeaders: true
        )
        
        Logger.shared.warning("ZIP export: Image bundling not yet implemented")
        
        // Rename to .zip extension
        let zipFilename = generateFilename(date: Date(), extension: "zip")
        let zipURL = FileManager.default.temporaryDirectory.appendingPathComponent(zipFilename)
        
        try? FileManager.default.removeItem(at: zipURL)
        try FileManager.default.copyItem(at: csvURL, to: zipURL)
        
        return zipURL
    }
    
    // MARK: - CSV Generation
    
    private func generateCSVHeader() -> String {
        // Match exact spreadsheet format
        let headers = [
            "date",
            "Register",
            "Ring",
            "Cashier #",
            "B.O.B (Y/N)",
            "3/ TOTAL (Y/N)",
            "PRESCAN Y/N",
            "PRESCAN # BASKET # Y/N",
            "ITEM # OVERCHARGE",
            "ITEM # UNDERCHARGE",
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
        
        return headers.joined(separator: ",") + "\n"
    }
    
    private func generateCSVRow(receipt: Receipt, lineItem: LineItem?, audit: AuditData?) -> String {
        // Receipt-level information (same for all line items in a receipt)
        let date = (receipt.purchaseDate ?? receipt.timestamp).receiptString
        let register = receipt.registerNumber ?? ""
        let ring = receipt.transactionNumber ?? "" // "Ring" is the transaction number
        let cashierNumber = receipt.cashierNumber ?? ""
        
        // Parse audit checks from notes
        let (bob, threeTotal, prescan, prescanMatch) = parseAuditChecks(audit?.notes)
        
        // Parse overcharge/undercharge item numbers from issues
        let (overchargeItemNumber, underchargeItemNumber) = parseItemNumbers(audit?.issue1, audit?.issue2)
        
        // Line item information
        let itemName = lineItem?.description ?? ""
        let quantity = lineItem?.quantity.map { String($0) } ?? ""
        let cost = lineItem?.price.map { String(format: "%.2f", $0) } ?? ""
        let total = lineItem?.total.map { String(format: "$%.2f", $0) } ?? ""
        
        // Only show overcharge/undercharge item number if this line item matches
        let currentItemNumber = lineItem?.itemNumber.map { String($0) } ?? ""
        let displayOvercharge = (!overchargeItemNumber.isEmpty && currentItemNumber == overchargeItemNumber) ? overchargeItemNumber : ""
        let displayUndercharge = (!underchargeItemNumber.isEmpty && currentItemNumber == underchargeItemNumber) ? underchargeItemNumber : ""
        
        // Staff information
        let security = audit?.staffName ?? ""
        let supervisor = audit?.auditorName ?? ""
        let (cashierName, assistant, week) = parseStaffFromNotes(audit?.notes)
        
        // Build row matching spreadsheet format
        let row = [
            date,
            register,
            ring,
            cashierNumber,
            bob ? "Y" : "N",
            threeTotal ? "Y" : "N",
            prescan ? "Y" : "N",
            prescanMatch ? "Y" : "N",
            displayOvercharge,
            displayUndercharge,
            escapeCSV(itemName),
            quantity,
            cost,
            total,
            escapeCSV(security),
            escapeCSV(cashierName),
            escapeCSV(assistant),
            escapeCSV(supervisor),
            escapeCSV(week)
        ].joined(separator: ",")
        
        return row + "\n"
    }
    
    /// Parse audit checks from notes
    /// Notes format: "BOB: Y | 3/TOTAL: Y | PRESCAN: Y | PRESCAN MATCH: Y | ..."
    private func parseAuditChecks(_ notes: String?) -> (bob: Bool, threeTotal: Bool, prescan: Bool, prescanMatch: Bool) {
        guard let notes = notes else {
            return (false, false, false, false)
        }
        
        var bob = false
        var threeTotal = false
        var prescan = false
        var prescanMatch = false
        
        let components = notes.components(separatedBy: "|")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("BOB:") {
                bob = trimmed.contains("Y")
            } else if trimmed.hasPrefix("3/TOTAL:") {
                threeTotal = trimmed.contains("Y")
            } else if trimmed.hasPrefix("PRESCAN:") && !trimmed.contains("MATCH") {
                prescan = trimmed.contains("Y")
            } else if trimmed.hasPrefix("PRESCAN MATCH:") {
                prescanMatch = trimmed.contains("Y")
            }
        }
        
        return (bob, threeTotal, prescan, prescanMatch)
    }
    
    /// Parse item numbers from overcharge/undercharge issues
    /// Issue format: "OVERCHARGE: #12345 - Item Name - $5.99" or "UNDERCHARGE: #12345 - Item Name - $5.99"
    private func parseItemNumbers(_ issue1: String?, _ issue2: String?) -> (overcharge: String, undercharge: String) {
        var overchargeItemNumber = ""
        var underchargeItemNumber = ""
        
        // Parse issue1 (typically overcharge)
        if let issue1 = issue1, issue1.contains("OVERCHARGE") {
            // Extract item number after "#"
            if let hashIndex = issue1.firstIndex(of: "#") {
                let afterHash = String(issue1[issue1.index(after: hashIndex)...])
                if let dashIndex = afterHash.firstIndex(of: "-") {
                    overchargeItemNumber = String(afterHash[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                } else {
                    overchargeItemNumber = afterHash.trimmingCharacters(in: .whitespaces)
                }
            }
        } else if let issue1 = issue1, issue1.contains("UNDERCHARGE") {
            // Sometimes issue1 might be undercharge
            if let hashIndex = issue1.firstIndex(of: "#") {
                let afterHash = String(issue1[issue1.index(after: hashIndex)...])
                if let dashIndex = afterHash.firstIndex(of: "-") {
                    underchargeItemNumber = String(afterHash[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                } else {
                    underchargeItemNumber = afterHash.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Parse issue2 (typically undercharge)
        if let issue2 = issue2, issue2.contains("UNDERCHARGE") {
            if let hashIndex = issue2.firstIndex(of: "#") {
                let afterHash = String(issue2[issue2.index(after: hashIndex)...])
                if let dashIndex = afterHash.firstIndex(of: "-") {
                    underchargeItemNumber = String(afterHash[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                } else {
                    underchargeItemNumber = afterHash.trimmingCharacters(in: .whitespaces)
                }
            }
        } else if let issue2 = issue2, issue2.contains("OVERCHARGE") {
            // Sometimes issue2 might be overcharge
            if let hashIndex = issue2.firstIndex(of: "#") {
                let afterHash = String(issue2[issue2.index(after: hashIndex)...])
                if let dashIndex = afterHash.firstIndex(of: "-") {
                    overchargeItemNumber = String(afterHash[..<dashIndex]).trimmingCharacters(in: .whitespaces)
                } else {
                    overchargeItemNumber = afterHash.trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        return (overchargeItemNumber, underchargeItemNumber)
    }
    
    /// Parse staff information from audit notes
    /// Notes format: "BOB: Y | 3/TOTAL: Y | Cashier: John | Asst: Jane | Sup: Bob | Week: Week 1"
    private func parseStaffFromNotes(_ notes: String?) -> (cashier: String, assistant: String, week: String) {
        guard let notes = notes else {
            return ("", "", "")
        }
        
        var cashier = ""
        var assistant = ""
        var week = ""
        
        let components = notes.components(separatedBy: "|")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("Cashier:") {
                cashier = String(trimmed.dropFirst("Cashier:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Asst:") {
                assistant = String(trimmed.dropFirst("Asst:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Week:") {
                week = String(trimmed.dropFirst("Week:".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return (cashier, assistant, week)
    }
    
    // MARK: - Helper Methods
    
    private func escapeCSV(_ value: String) -> String {
        // Escape quotes and wrap in quotes if contains comma/quote/newline
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
    
    private func generateFilename(date: Date, extension ext: String) -> String {
        let prefix = AppConstants.Export.csvFilenamePrefix
        let dateString = date.filenameString
        return "\(prefix)_\(dateString).\(ext)"
    }
    
    private func saveToTempFile(data: Data, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent(filename)
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: fileURL)
        
        // Write new file
        try data.write(to: fileURL)
        
        Logger.shared.info("File saved: \(fileURL.path)")
        Logger.shared.info("File size: \(data.count) bytes")
        
        return fileURL
    }
}

// MARK: - Export Service Errors

enum ExportServiceError: LocalizedError {
    case noData
    case csvGenerationFailed
    case zipCreationFailed
    case fileWriteFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No data to export"
        case .csvGenerationFailed:
            return "Failed to generate CSV"
        case .zipCreationFailed:
            return "Failed to create ZIP archive"
        case .fileWriteFailed(let error):
            return "Failed to write file: \(error.localizedDescription)"
        }
    }
}
