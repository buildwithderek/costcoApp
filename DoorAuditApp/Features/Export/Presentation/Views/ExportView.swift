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
            VStack(spacing: 24) {
                // Header illustration
                exportIllustration
                
                // Stats
                statsSection
                
                // Export Button
                exportButton
                
                Spacer()
                
                // Info text
                infoText
            }
            .padding()
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
    
    private var statsSection: some View {
        VStack(spacing: 12) {
            Text("Today's Audits")
                .font(.headline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 40) {
                VStack {
                    Text("\(todaysReceiptCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(CostcoTheme.Colors.primary)
                    Text("Receipts")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                VStack {
                    Text("\(completedAuditCount)")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(CostcoTheme.Colors.success)
                    Text("Audited")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
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
                    Text(isExporting ? "Generating..." : "Export to CSV")
                        .font(.headline)
                    Text("Preview & share via email")
                        .font(.caption)
                        .opacity(0.8)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                todaysReceiptCount == 0
                    ? Color.gray
                    : CostcoTheme.Colors.primary
            )
            .cornerRadius(16)
        }
        .disabled(isExporting || todaysReceiptCount == 0)
    }
    
    private var infoText: some View {
        VStack(spacing: 8) {
            Text("The CSV file will match your spreadsheet format")
                .font(.footnote)
                .foregroundColor(.secondary)
            
            Text("You can email it, save to Files, or open in Numbers")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .multilineTextAlignment(.center)
    }
    
    // MARK: - Methods
    
    private func loadStats() async {
        do {
            let receipts = try await dependencies.fetchReceiptsUseCase.fetchTodaysReceipts()
            todaysReceiptCount = receipts.count
            
            // Count completed audits
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
