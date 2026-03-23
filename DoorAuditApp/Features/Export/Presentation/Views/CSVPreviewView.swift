//
//  CSVPreviewView.swift
//  DoorAuditApp
//
//  CSV preview before export with table display
//  Shows data in a scrollable table format
//  Created: December 2025
//

import SwiftUI

// MARK: - CSV Preview View

struct CSVPreviewView: View {
    let csvURL: URL
    let onExport: () -> Void
    let onCancel: () -> Void

    @State private var headers: [String] = []
    @State private var rows: [[String]] = []
    @State private var parseError: String?
    @State private var totalRowCount: Int = 0
    @State private var isLoading = true

    private let previewLimit = 50

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Export Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel", action: onCancel)
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button {
                            onExport()
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                        }
                        .disabled(isLoading || parseError != nil)
                    }
                }
                .task {
                    await loadCSV()
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            loadingView
        } else if let error = parseError {
            errorView(error)
        } else if headers.isEmpty {
            errorView("No data found in CSV")
        } else {
            ScrollView {
                VStack(spacing: CostcoTheme.Spacing.md) {
                    overviewCard
                    summaryBar
                    csvTable
                }
                .padding()
            }
            .background(CostcoTheme.Colors.background)
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        ContentUnavailableView {
            Label("Loading preview", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("Preparing a preview of the export file.")
        }
    }

    // MARK: - Overview

    private var overviewCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text(csvURL.lastPathComponent)
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            Text("Review the first \(min(totalRowCount, previewLimit)) row\(min(totalRowCount, previewLimit) == 1 ? "" : "s") before sharing the export.")
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)

            HStack(spacing: 8) {
                previewChip(title: "\(headers.count) columns", systemImage: "rectangle.split.3x1")
                previewChip(title: "\(totalRowCount) rows", systemImage: "tablecells")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .costcoCard()
    }

    private func previewChip(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundColor(CostcoTheme.Colors.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(CostcoTheme.Colors.primary.opacity(0.12))
            .cornerRadius(999)
    }

    // MARK: - Summary Bar

    private var summaryBar: some View {
        HStack {
            Label("\(totalRowCount) audit\(totalRowCount == 1 ? "" : "s")", systemImage: "tablecells")

            Spacer()

            if totalRowCount > previewLimit {
                Text("Showing first \(previewLimit)")
                    .foregroundColor(.secondary)
            }

            if let attrs = try? FileManager.default.attributesOfItem(atPath: csvURL.path),
               let size = attrs[.size] as? Int64 {
                Text("•")
                    .foregroundColor(.secondary)
                Text(formatFileSize(size))
                    .foregroundColor(.secondary)
            }
        }
        .font(.caption)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - CSV Table

    private var csvTable: some View {
        ScrollView([.horizontal, .vertical]) {
            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                Section {
                    ForEach(rows.indices, id: \.self) { rowIndex in
                        rowView(for: rowIndex)
                    }
                } header: {
                    headerRow
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }

    private var headerRow: some View {
        HStack(spacing: 0) {
            ForEach(headers.indices, id: \.self) { index in
                Text(headers[index])
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .frame(width: columnWidth(for: index), alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
            }
        }
        .background(CostcoTheme.Colors.primary)
        .foregroundColor(.white)
    }

    private func rowView(for rowIndex: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<headers.count, id: \.self) { colIndex in
                let value = colIndex < rows[rowIndex].count ? rows[rowIndex][colIndex] : ""
                Text(value)
                    .font(.system(.caption, design: .monospaced))
                    .lineLimit(2)
                    .frame(width: columnWidth(for: colIndex), alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .background(rowIndex % 2 == 0 ? Color.clear : Color(.systemGray6))
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ error: String) -> some View {
        ContentUnavailableView {
            Label("Preview unavailable", systemImage: "exclamationmark.triangle")
        } description: {
            Text(error)
        } actions: {
            Text(csvURL.lastPathComponent)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Helper Methods

    private func columnWidth(for index: Int) -> CGFloat {
        guard index < headers.count else { return 100 }

        let header = headers[index].lowercased()

        if header.contains("date") { return 100 }
        if header.contains("register") || header.contains("ring") { return 70 }
        if header.contains("y/n") { return 50 }
        if header.contains("item #") { return 80 }
        if header.contains("name") { return 150 }
        if header.contains("cost") || header.contains("total") { return 80 }
        if header.contains("member") { return 120 }
        if header.contains("week") { return 70 }

        return 100
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    @MainActor
    private func loadCSV() async {
        isLoading = true

        try? await Task.sleep(nanoseconds: 200_000_000)

        do {
            guard FileManager.default.fileExists(atPath: csvURL.path) else {
                parseError = "File not found: \(csvURL.lastPathComponent)"
                isLoading = false
                return
            }

            let content = try String(contentsOf: csvURL, encoding: .utf8)

            guard !content.isEmpty else {
                parseError = "File is empty"
                isLoading = false
                return
            }

            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }

            guard let headerLine = lines.first else {
                parseError = "CSV file has no header row"
                isLoading = false
                return
            }

            headers = parseCSVLine(headerLine)
            totalRowCount = max(0, lines.count - 1)

            let dataLines = Array(lines.dropFirst().prefix(previewLimit))
            rows = dataLines.map { parseCSVLine($0) }

            isLoading = false

            Logger.shared.info("CSV preview loaded: \(headers.count) columns, \(totalRowCount) rows")

        } catch {
            parseError = "Failed to read file: \(error.localizedDescription)"
            isLoading = false
            Logger.shared.error("CSV parse error", error: error)
        }
    }

    private func parseCSVLine(_ line: String) -> [String] {
        var fields: [String] = []
        var field = ""
        var inQuotes = false

        var i = line.startIndex
        while i < line.endIndex {
            let ch = line[i]

            if ch == "\"" {
                let next = line.index(after: i)
                if inQuotes, next < line.endIndex, line[next] == "\"" {
                    field.append("\"")
                    i = line.index(after: next)
                    continue
                } else {
                    inQuotes.toggle()
                    i = line.index(after: i)
                    continue
                }
            }

            if ch == "," && !inQuotes {
                fields.append(field.trimmingCharacters(in: .whitespaces))
                field = ""
                i = line.index(after: i)
                continue
            }

            field.append(ch)
            i = line.index(after: i)
        }

        fields.append(field.trimmingCharacters(in: .whitespaces))
        return fields
    }
}

// MARK: - CSV Export Flow Modifier

struct CSVExportFlowModifier: ViewModifier {
    @Binding var csvURL: URL?
    @Binding var showPreview: Bool
    @Binding var showShareSheet: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $showPreview) {
                if let url = csvURL {
                    CSVPreviewView(
                        csvURL: url,
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
                } else {
                    noDataView
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = csvURL {
                    ShareSheet(activityItems: [url])
                }
            }
    }

    private var noDataView: some View {
        ContentUnavailableView {
            Label("No CSV file to preview", systemImage: "exclamationmark.triangle")
        } description: {
            Text("The export finished before a preview file was available.")
        } actions: {
            Button("Close") {
                showPreview = false
            }
        }
    }
}

extension View {
    func csvExportFlow(
        csvURL: Binding<URL?>,
        showPreview: Binding<Bool>,
        showShareSheet: Binding<Bool>
    ) -> some View {
        modifier(CSVExportFlowModifier(
            csvURL: csvURL,
            showPreview: showPreview,
            showShareSheet: showShareSheet
        ))
    }
}

// MARK: - Preview

#Preview {
    CSVPreviewView(
        csvURL: URL(fileURLWithPath: "/tmp/test.csv"),
        onExport: {},
        onCancel: {}
    )
}
