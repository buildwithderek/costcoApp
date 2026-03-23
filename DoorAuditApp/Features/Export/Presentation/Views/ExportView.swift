//
//  ExportView.swift
//  DoorAuditApp
//
//  Export view with one-tap export button
//  Shows CSV preview before sharing via email/files
//  Created: December 2025
//

import SwiftUI

// MARK: - Export View

struct ExportView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var isExporting = false
    @State private var exportResult: ExportResult?
    @State private var exportError: Error?

    @State private var showPreview = false
    @State private var showShareSheet = false

    @State private var todaysReceiptCount = 0
    @State private var completedAuditCount = 0

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    exportIllustration
                    summaryCard

                    if todaysReceiptCount == 0 {
                        emptyState
                    } else {
                        exportButton
                        infoCard
                    }
                }
                .padding()
            }
            .background(CostcoTheme.Colors.background)
            .navigationTitle("Export Audits")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .task {
                await loadStats()
            }
            .alert("Export Error", isPresented: Binding(
                get: { exportError != nil },
                set: { if !$0 { exportError = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(exportError?.localizedDescription ?? "Unknown error")
            }
            .sheet(isPresented: $showPreview) {
                if let result = exportResult {
                    CSVPreviewView(
                        csvURL: result.fileURL,
                        onExport: {
                            showPreview = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                                showShareSheet = true
                            }
                        },
                        onCancel: {
                            showPreview = false
                        }
                    )
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let result = exportResult {
                    ShareSheet(activityItems: [result.fileURL])
                }
            }
        }
    }

    // MARK: - Subviews

    private var exportIllustration: some View {
        ZStack {
            Circle()
                .fill(CostcoTheme.Colors.primary.opacity(0.1))
                .frame(width: 120, height: 120)

            Image(systemName: "square.and.arrow.up.on.square.fill")
                .font(.system(size: 48))
                .foregroundColor(CostcoTheme.Colors.primary)
        }
        .padding(.top, 20)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today’s export")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            Text(todaysReceiptCount == 0
                 ? "There are no receipts ready to export yet."
                 : "Review today’s totals, then generate a CSV preview before sharing.")
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)

            HStack(spacing: 40) {
                statValue(title: "Receipts", value: "\(todaysReceiptCount)", color: CostcoTheme.Colors.primary)
                statValue(title: "Audited", value: "\(completedAuditCount)", color: CostcoTheme.Colors.success)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .costcoCard()
    }

    private func statValue(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(value)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(color)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    private var exportButton: some View {
        Button {
            Task {
                await exportTodaysAudits()
            }
        } label: {
            HStack(spacing: 12) {
                if isExporting {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.title2)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(isExporting ? "Generating preview..." : "Export today’s CSV")
                        .font(.headline)
                    Text("Open the preview, then share the file.")
                        .font(.caption)
                        .opacity(0.85)
                }

                Spacer()
            }
            .costcoPrimaryButton()
        }
        .disabled(isExporting || todaysReceiptCount == 0)
    }

    private var infoCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("What happens next")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            Label("Preview the CSV before sending it.", systemImage: "doc.text.magnifyingglass")
            Label("Share with Mail, Files, or Numbers.", systemImage: "square.and.arrow.up")
        }
        .font(CostcoTheme.Typography.subheadline)
        .foregroundColor(CostcoTheme.Colors.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .costcoCard()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Nothing to export yet", systemImage: "tray")
        } description: {
            Text("Scan and audit a receipt first, then come back here to export the day’s CSV.")
        }
    }

    // MARK: - Methods

    private func loadStats() async {
        do {
            let receipts = try await dependencies.fetchReceiptsUseCase.fetchTodaysReceipts()
            todaysReceiptCount = receipts.count

            var completed = 0
            for receipt in receipts {
                if let audit = try? await dependencies.auditRepository.fetchAudit(for: receipt.id),
                   !audit.staffName.isEmpty {
                    completed += 1
                }
            }
            completedAuditCount = completed

        } catch {
            Logger.shared.error("Failed to load stats", error: error)
        }
    }

    private func exportTodaysAudits() async {
        isExporting = true
        exportError = nil

        do {
            let result = try await dependencies.exportAuditsUseCase.exportTodaysAudits()

            await MainActor.run {
                exportResult = result
                isExporting = false
                showPreview = true
            }

        } catch {
            await MainActor.run {
                exportError = error
                isExporting = false
            }
        }
    }
}

// MARK: - Quick Export Button (for embedding in other views)

struct QuickExportButton: View {
    @Environment(\.dependencies) private var dependencies

    @State private var isExporting = false
    @State private var exportResult: ExportResult?
    @State private var exportError: Error?
    @State private var showPreview = false
    @State private var showShareSheet = false

    var body: some View {
        Button {
            Task {
                await exportTodaysAudits()
            }
        } label: {
            HStack(spacing: 8) {
                if isExporting {
                    ProgressView()
                        .tint(CostcoTheme.Colors.primary)
                } else {
                    Image(systemName: "square.and.arrow.up")
                }
                Text(isExporting ? "Exporting..." : "Export Today")
            }
            .font(.subheadline.weight(.medium))
            .foregroundColor(CostcoTheme.Colors.primary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(CostcoTheme.Colors.primary.opacity(0.1))
            .cornerRadius(20)
        }
        .disabled(isExporting)
        .alert("Export Error", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError?.localizedDescription ?? "Unknown error")
        }
        .sheet(isPresented: $showPreview) {
            if let result = exportResult {
                CSVPreviewView(
                    csvURL: result.fileURL,
                    onExport: {
                        showPreview = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            showShareSheet = true
                        }
                    },
                    onCancel: {
                        showPreview = false
                    }
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let result = exportResult {
                ShareSheet(activityItems: [result.fileURL])
            }
        }
    }

    private func exportTodaysAudits() async {
        isExporting = true
        exportError = nil

        do {
            let result = try await dependencies.exportAuditsUseCase.exportTodaysAudits()

            await MainActor.run {
                exportResult = result
                isExporting = false
                showPreview = true
            }

        } catch {
            await MainActor.run {
                exportError = error
                isExporting = false
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ExportView()
        .environment(\.dependencies, DependencyContainer.shared)
}
