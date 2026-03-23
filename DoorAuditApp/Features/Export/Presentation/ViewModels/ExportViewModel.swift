//
//  ExportViewModel.swift
//  L1 Demo
//
//  ViewModel for export functionality
//  Handles: CSV export, ZIP export with images, date selection
//  Created: December 2025
//

import Foundation
import SwiftUI
import Observation

/// ViewModel for export screens
@Observable
final class ExportViewModel {

    // MARK: - State

    var selectedDate = Date()
    var exportFormat: UIExportFormat = .csv
    var includeImages = false
    var isExporting = false
    var error: Error?

    // Export result
    var exportURL: URL?
    var showShareSheet = false

    // Preview data
    var receiptsToExport: [Receipt] = []
    var auditsToExport: [AuditData] = []
    var previewCSV: String = ""

    // MARK: - Export Format (UI wrapper for ExportFormat from ExportAuditsUseCase)

    enum UIExportFormat: String, CaseIterable {
        case csv = "CSV"
        case zip = "ZIP (with images)"

        var displayName: String { rawValue }

        var fileExtension: String {
            switch self {
            case .csv: return "csv"
            case .zip: return "zip"
            }
        }

        /// Convert to ExportFormat from ExportAuditsUseCase
        var useCaseFormat: ExportFormat {
            switch self {
            case .csv: return ExportFormat.csv
            case .zip: return ExportFormat.zip
            }
        }
    }

    // MARK: - Dependencies

    private let exportAudits: ExportAuditsUseCase
    private let fetchReceipts: FetchReceiptsUseCase

    // MARK: - Initialization

    init(
        exportAudits: ExportAuditsUseCase,
        fetchReceipts: FetchReceiptsUseCase
    ) {
        self.exportAudits = exportAudits
        self.fetchReceipts = fetchReceipts
    }

    // MARK: - Computed Properties

    var canExport: Bool {
        !receiptsToExport.isEmpty
    }

    var exportCount: Int {
        receiptsToExport.count
    }

    var exportSummary: String {
        let receiptCount = receiptsToExport.count
        let auditCount = auditsToExport.count

        if receiptCount == 0 {
            return "No receipts for selected date"
        }

        return "\(receiptCount) receipt\(receiptCount == 1 ? "" : "s"), \(auditCount) audit\(auditCount == 1 ? "" : "s")"
    }

    var selectedDateLabel: String {
        selectedDate.displayString
    }

    var primaryActionTitle: String {
        canExport ? "Export \(exportCount) Receipt\(exportCount == 1 ? "" : "s")" : "No Receipts to Export"
    }

    var primaryActionSubtitle: String {
        canExport ? "\(exportFormat.displayName) • \(filename)" : "Choose a date with captured receipts"
    }

    var previewDescription: String {
        guard canExport else {
            return "Preview will appear when receipts are available for the selected date."
        }

        let previewCount = min(exportCount, 5)
        return "Showing the first \(previewCount) row\(previewCount == 1 ? "" : "s") from \(filename)."
    }

    var filename: String {
        let dateString = selectedDate.filenameString
        let prefix = AppConstants.Export.csvFilenamePrefix

        switch exportFormat {
        case .csv:
            return "\(prefix)_\(dateString).csv"
        case .zip:
            return "\(prefix)_\(dateString).zip"
        }
    }

    // MARK: - Actions

    /// Load receipts for selected date
    @MainActor
    func loadReceiptsForDate() async {
        do {
            receiptsToExport = try await fetchReceipts.fetchReceipts(for: selectedDate)

            // Load audits for these receipts
            // (Will implement when audit repository is integrated)
            auditsToExport = []

            Logger.shared.info("Loaded \(receiptsToExport.count) receipts for \(selectedDate.displayString)")

            // Generate preview
            await generatePreview()

        } catch {
            Logger.shared.error("Failed to load receipts", error: error)
            self.error = error
        }
    }

    /// Generate CSV preview
    @MainActor
    private func generatePreview() async {
        guard !receiptsToExport.isEmpty else {
            previewCSV = "No data to preview"
            return
        }

        // Generate a preview of the first few rows
        var preview = "Date,Register,Transaction,Barcode,Total,Staff,Issues\n"

        for receipt in receiptsToExport.prefix(5) {
            let date = receipt.purchaseDate?.receiptString ?? receipt.timestamp.receiptString
            let register = receipt.registerNumber ?? "-"
            let transaction = receipt.transactionNumber ?? "-"
            let barcode = receipt.barcodeValue ?? "-"
            let total = receipt.formattedTotal ?? "-"
            let staff = "-" // Will get from audit
            let issues = "-" // Will get from audit

            preview += "\(date),\(register),\(transaction),\(barcode),\(total),\(staff),\(issues)\n"
        }

        if receiptsToExport.count > 5 {
            preview += "... and \(receiptsToExport.count - 5) more rows\n"
        }

        previewCSV = preview
    }

    /// Export data
    @MainActor
    func export() async {
        guard canExport else {
            error = ExportError.noData
            return
        }

        isExporting = true
        error = nil
        exportURL = nil

        do {
            Logger.shared.info("Starting export: \(exportFormat.displayName)")

            // Execute export use case
            let result = try await exportAudits.execute(
                receipts: receiptsToExport,
                audits: auditsToExport,
                format: exportFormat.useCaseFormat,
                includeImages: includeImages,
                date: selectedDate
            )

            exportURL = result.fileURL
            showShareSheet = true

            Logger.shared.success("Export completed: \(filename)")

        } catch {
            Logger.shared.error("Export failed", error: error)
            self.error = error
        }

        isExporting = false
    }

    /// Change date
    @MainActor
    func changeDate(_ date: Date) async {
        selectedDate = date
        await loadReceiptsForDate()
    }

    /// Change format
    func changeFormat(_ format: UIExportFormat) {
        exportFormat = format

        // ZIP format automatically includes images
        if format == .zip {
            includeImages = true
        }
    }

    /// Toggle images
    func toggleImages() {
        includeImages.toggle()

        // If turning off images and format is ZIP, switch to CSV
        if !includeImages && exportFormat == .zip {
            exportFormat = .csv
        }
    }

    /// Dismiss share sheet
    func dismissShareSheet() {
        showShareSheet = false
    }

    /// Clear error
    func clearError() {
        error = nil
    }

    /// Reset
    func reset() {
        exportURL = nil
        error = nil
        showShareSheet = false
        isExporting = false
    }
}

// NOTE: ExportError is defined in ExportAuditsUseCase.swift

// MARK: - Preview

#if DEBUG
extension ExportViewModel {
    static var preview: ExportViewModel {
        let mockExport = MockExportAuditsUseCase()
        let mockFetch = MockFetchReceiptsUseCaseForExport()

        let vm = ExportViewModel(
            exportAudits: mockExport,
            fetchReceipts: mockFetch
        )

        // Populate with sample data
        vm.receiptsToExport = [.sample, .sample, .sample]
        vm.auditsToExport = [.sample, .sample]
        vm.previewCSV = "Date,Register,Transaction,Total\n12/24/2025,12,0056,$125.47\n12/24/2025,8,0123,$89.99\n"

        return vm
    }
}

// Mock implementations
private class MockExportAuditsUseCase: ExportAuditsUseCase {
    func execute(
        receipts: [Receipt],
        audits: [AuditData],
        format: ExportFormat,
        includeImages: Bool,
        date: Date
    ) async throws -> ExportResult {
        try await Task.sleep(for: .seconds(1))

        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("sample_export.csv")

        let csvData = "Sample CSV Data".data(using: .utf8)!
        try csvData.write(to: tempURL)

        return ExportResult(fileURL: tempURL, fileName: "sample.csv")
    }
}

private class MockFetchReceiptsUseCaseForExport: FetchReceiptsUseCase {
    func fetchAll() async throws -> [Receipt] { [] }

    func fetch(id: UUID) async throws -> Receipt? { nil }

    func fetchTodaysReceipts() async throws -> [Receipt] { [] }

    func fetchThisWeeksReceipts() async throws -> [Receipt] { [] }

    func fetchThisMonthsReceipts() async throws -> [Receipt] { [] }

    func fetchReceipts(for date: Date) async throws -> [Receipt] {
        [.sample, .sample]
    }

    func fetchReceipts(from startDate: Date, to endDate: Date) async throws -> [Receipt] { [] }

    func searchReceipts(query: String) async throws -> [Receipt] { [] }

    func count() async throws -> Int { 0 }

    func count(for date: Date) async throws -> Int { 0 }
}
#endif
