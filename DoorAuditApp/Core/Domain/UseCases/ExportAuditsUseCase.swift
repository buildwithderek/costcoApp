//
//  ExportAuditsUseCase.swift
//  DoorAuditApp
//
//  Use Case for exporting audits to CSV
//  Generates a CSV file matching your spreadsheet format
//  Created: December 2025
//

import Foundation

// MARK: - Export Audits Protocol

/// Exports audits in various formats
protocol ExportAuditsUseCase {
    /// Export today's audits
    func exportTodaysAudits() async throws -> ExportResult
    
    /// Export audits for a specific date
    func exportAudits(for date: Date) async throws -> ExportResult
    
    /// Export specific receipts with their audits
    func execute(
        receipts: [Receipt],
        audits: [AuditData],
        format: ExportFormat,
        includeImages: Bool,
        date: Date
    ) async throws -> ExportResult
}

// MARK: - Default Implementations

extension ExportAuditsUseCase {
    /// Default: exportTodaysAudits calls exportAudits with today's date
    func exportTodaysAudits() async throws -> ExportResult {
        try await exportAudits(for: Date())
    }
    
    /// Default: exportAudits calls execute with empty audits (for backward compatibility)
    func exportAudits(for date: Date) async throws -> ExportResult {
        try await execute(receipts: [], audits: [], format: .csv, includeImages: false, date: date)
    }
}

// MARK: - Default Implementation

final class DefaultExportAuditsUseCase: ExportAuditsUseCase {
    
    // MARK: - Dependencies
    
    private let receiptRepository: ReceiptRepository
    private let auditRepository: AuditRepository
    private let imageRepository: ImageRepository
    
    // MARK: - CSV Headers (matching your Google Sheets format)
    
    private static let csvHeaders = [
        "date",
        "Register",
        "Ring",
        "Cashier #",
        "B.O.B (Y/N)",
        "3/ TOTAL (Y/N)",
        "PRESCAN Y/N",
        "PRESCAN # = BASKET # Y/N",
        "ITEM # OVERCHARGE",
        "OVERCHARGE NAME",
        "OVERCHARGE COST",
        "ITEM # UNDERCHARGE",
        "UNDERCHARGE NAME",
        "UNDERCHARGE COST",
        "Total",
        "Security",
        "Cashier",
        "Asst.",
        "Supervisor",
        "Week",
        "Member ID"
    ]
    
    // MARK: - Initialization
    
    init(
        receiptRepository: ReceiptRepository,
        auditRepository: AuditRepository,
        imageRepository: ImageRepository
    ) {
        self.receiptRepository = receiptRepository
        self.auditRepository = auditRepository
        self.imageRepository = imageRepository
    }
    
    // MARK: - Convenience Methods
    
    func exportTodaysAudits() async throws -> ExportResult {
        try await exportAudits(for: Date())
    }
    
    func exportAudits(for date: Date) async throws -> ExportResult {
        Logger.shared.info("Exporting audits for \(date.displayString)...")
        
        // Fetch receipts for the date
        let receipts = try await receiptRepository.fetchReceipts(for: date)
        
        guard !receipts.isEmpty else {
            throw ExportError.noData
        }
        
        // Fetch audits for these receipts
        var audits: [AuditData] = []
        for receipt in receipts {
            if let audit = try await auditRepository.fetchAudit(for: receipt.id) {
                audits.append(audit)
            }
        }
        
        return try await execute(
            receipts: receipts,
            audits: audits,
            format: .csv,
            includeImages: false,
            date: date
        )
    }
    
    // MARK: - Main Execute
    
    func execute(
        receipts: [Receipt],
        audits: [AuditData],
        format: ExportFormat,
        includeImages: Bool,
        date: Date
    ) async throws -> ExportResult {
        Logger.shared.info("Starting export: format=\(format), receipts=\(receipts.count), audits=\(audits.count)")
        
        guard !receipts.isEmpty else {
            throw ExportError.noData
        }
        
        // Create audit lookup dictionary
        let auditLookup = Dictionary(
            uniqueKeysWithValues: audits.map { ($0.receiptID, $0) }
        )
        
        // Generate filename
        let filename = generateFilename(date: date, format: format)
        
        // Generate CSV content
        let csvContent = generateCSV(receipts: receipts, auditLookup: auditLookup)
        
        // Save to file
        let fileURL = try saveToFile(content: csvContent, filename: filename)
        
        Logger.shared.success("Export completed: \(filename)")
        
        return ExportResult(fileURL: fileURL, fileName: filename)
    }
    
    // MARK: - CSV Generation
    
    private func generateCSV(receipts: [Receipt], auditLookup: [UUID: AuditData]) -> String {
        var lines: [String] = []
        
        // Add header row
        lines.append(Self.csvHeaders.joined(separator: ","))
        
        // Add data rows - one row per receipt
        for receipt in receipts {
            let audit = auditLookup[receipt.id]
            let row = generateCSVRow(receipt: receipt, audit: audit)
            lines.append(row)
        }
        
        return lines.joined(separator: "\n") + "\n"
    }
    
    private func generateCSVRow(receipt: Receipt, audit: AuditData?) -> String {
        // Parse audit data
        let auditInfo = parseAuditInfo(audit)
        let issueInfo = parseIssueInfo(audit)
        
        // Build row data
        let rowData: [String] = [
            // Date
            formatDate(receipt.purchaseDate ?? receipt.timestamp),
            
            // Register
            receipt.registerNumber ?? "",
            
            // Ring (transaction number)
            receipt.transactionNumber ?? "",
            
            // Cashier #
            receipt.cashierNumber ?? "",
            
            // B.O.B (Y/N)
            auditInfo.bob ? "Y" : "N",
            
            // 3/ TOTAL (Y/N)
            auditInfo.threeTotal ? "Y" : "N",
            
            // PRESCAN Y/N
            auditInfo.prescan ? "Y" : "N",
            
            // PRESCAN # = BASKET # Y/N
            auditInfo.prescanMatch ? "Y" : "N",
            
            // ITEM # OVERCHARGE
            issueInfo.overchargeNumber,
            
            // OVERCHARGE NAME
            issueInfo.overchargeName,
            
            // OVERCHARGE COST
            issueInfo.overchargeCost.isEmpty ? "" : "$\(issueInfo.overchargeCost)",
            
            // ITEM # UNDERCHARGE
            issueInfo.underchargeNumber,
            
            // UNDERCHARGE NAME
            issueInfo.underchargeName,
            
            // UNDERCHARGE COST
            issueInfo.underchargeCost.isEmpty ? "" : "$\(issueInfo.underchargeCost)",
            
            // Total
            receipt.totalAmount.map { String(format: "$%.2f", $0) } ?? "",
            
            // Security
            audit?.staffName ?? "",
            
            // Cashier (from notes)
            auditInfo.cashier,
            
            // Asst. (from notes)
            auditInfo.assistant,
            
            // Supervisor
            audit?.auditorName ?? "",
            
            // Week
            auditInfo.week,
            
            // Member ID
            receipt.memberID ?? ""
        ]
        
        // Escape and join
        return rowData.map { escapeCSV($0) }.joined(separator: ",")
    }
    
    // MARK: - Parsing Helpers
    
    private struct AuditInfo {
        var bob = false
        var threeTotal = false
        var prescan = false
        var prescanMatch = false
        var cashier = ""
        var assistant = ""
        var week = ""
    }
    
    private struct IssueInfo {
        var overchargeNumber = ""
        var overchargeName = ""
        var overchargeCost = ""
        var underchargeNumber = ""
        var underchargeName = ""
        var underchargeCost = ""
    }
    
    private func parseAuditInfo(_ audit: AuditData?) -> AuditInfo {
        guard let notes = audit?.notes else {
            return AuditInfo()
        }
        
        var info = AuditInfo()
        
        let components = notes.components(separatedBy: "|")
        for component in components {
            let trimmed = component.trimmingCharacters(in: .whitespaces)
            
            if trimmed.hasPrefix("BOB:") {
                info.bob = trimmed.contains("Y")
            } else if trimmed.hasPrefix("3/TOTAL:") {
                info.threeTotal = trimmed.contains("Y")
            } else if trimmed.hasPrefix("PRESCAN:") && !trimmed.contains("MATCH") {
                info.prescan = trimmed.contains("Y")
            } else if trimmed.hasPrefix("PRESCAN MATCH:") {
                info.prescanMatch = trimmed.contains("Y")
            } else if trimmed.hasPrefix("Cashier:") {
                info.cashier = String(trimmed.dropFirst("Cashier:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Asst:") {
                info.assistant = String(trimmed.dropFirst("Asst:".count)).trimmingCharacters(in: .whitespaces)
            } else if trimmed.hasPrefix("Week:") {
                info.week = String(trimmed.dropFirst("Week:".count)).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return info
    }
    
    private func parseIssueInfo(_ audit: AuditData?) -> IssueInfo {
        var info = IssueInfo()
        
        // Parse issue1
        if let issue1 = audit?.issue1 {
            if issue1.contains("OVERCHARGE") {
                parseIssueString(issue1, number: &info.overchargeNumber, name: &info.overchargeName, cost: &info.overchargeCost)
            } else if issue1.contains("UNDERCHARGE") {
                parseIssueString(issue1, number: &info.underchargeNumber, name: &info.underchargeName, cost: &info.underchargeCost)
            }
        }
        
        // Parse issue2
        if let issue2 = audit?.issue2 {
            if issue2.contains("UNDERCHARGE") {
                parseIssueString(issue2, number: &info.underchargeNumber, name: &info.underchargeName, cost: &info.underchargeCost)
            } else if issue2.contains("OVERCHARGE") {
                parseIssueString(issue2, number: &info.overchargeNumber, name: &info.overchargeName, cost: &info.overchargeCost)
            }
        }
        
        return info
    }
    
    private func parseIssueString(_ issue: String, number: inout String, name: inout String, cost: inout String) {
        // Format: "OVERCHARGE: #12345 - Item Name - $5.99"
        guard let hashIndex = issue.firstIndex(of: "#") else { return }
        
        let afterHash = String(issue[issue.index(after: hashIndex)...])
        let parts = afterHash.components(separatedBy: " - ")
        
        if parts.count >= 1 {
            number = parts[0].trimmingCharacters(in: .whitespaces)
        }
        if parts.count >= 2 {
            name = parts[1].trimmingCharacters(in: .whitespaces)
        }
        if parts.count >= 3 {
            cost = parts[2].replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces)
        }
    }
    
    // MARK: - Utility Methods
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }
    
    private func escapeCSV(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmed.contains(",") || trimmed.contains("\"") || trimmed.contains("\n") {
            let escaped = trimmed.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        
        return trimmed
    }
    
    private func generateFilename(date: Date, format: ExportFormat) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM-dd-yyyy_HHmmss"
        let dateString = formatter.string(from: date)
        let uniqueID = UUID().uuidString.prefix(6)
        
        return "Costco_Audit_\(dateString)_\(uniqueID).\(format.fileExtension)"
    }
    
    private func saveToFile(content: String, filename: String) throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        
        // Ensure filename has .csv extension
        let csvFilename: String
        if filename.hasSuffix(".csv") {
            csvFilename = filename
        } else if filename.hasSuffix(".txt") {
            csvFilename = String(filename.dropLast(4)) + ".csv"
        } else {
            csvFilename = filename + ".csv"
        }
        
        let fileURL = tempDir.appendingPathComponent(csvFilename)
        
        // Remove existing file if present
        try? FileManager.default.removeItem(at: fileURL)
        
        // Write new file with UTF-8 encoding
        try content.write(to: fileURL, atomically: true, encoding: .utf8)
        
        // The .csv file extension is sufficient for the system to recognize it as a CSV file
        // iOS and macOS will automatically associate .csv files with the correct content type
        
        // Verify
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            throw ExportError.fileWriteFailed
        }
        
        Logger.shared.info("CSV saved: \(fileURL.path), size: \(content.count) bytes, extension: \(fileURL.pathExtension)")
        
        return fileURL
    }
}

// MARK: - Export Format

enum ExportFormat {
    case csv
    case zip
    
    var fileExtension: String {
        switch self {
        case .csv: return "csv"
        case .zip: return "zip"
        }
    }
}

// MARK: - Export Result

struct ExportResult {
    let fileURL: URL
    let fileName: String
}

// MARK: - Export File (for sharing)

struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Export Errors

enum ExportError: LocalizedError {
    case noData
    case generationFailed
    case fileWriteFailed
    case invalidFormat
    
    var errorDescription: String? {
        switch self {
        case .noData:
            return "No audit data to export. Complete at least one audit first."
        case .generationFailed:
            return "Failed to generate export file"
        case .fileWriteFailed:
            return "Failed to write file to disk"
        case .invalidFormat:
            return "Invalid export format"
        }
    }
}
