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
            VStack(spacing: 0) {
                summaryBar
                csvTable
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading preview...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            
            // File size
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
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            
            Text("Failed to load preview")
                .font(.headline)
            
            Text(error)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Text("File: \(csvURL.lastPathComponent)")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Helper Methods
    
    private func columnWidth(for index: Int) -> CGFloat {
        guard index < headers.count else { return 100 }
        
        let header = headers[index].lowercased()
        
        // Adjust width based on column type
        if header.contains("date") { return 100 }
        if header.contains("register") || header.contains("ring") { return 70 }
        if header.contains("y/n") { return 50 }
        if header.contains("item #") { return 80 }
        if header.contains("name") { return 150 }
        if header.contains("cost") || header.contains("total") { return 80 }
        if header.contains("member") { return 120 }
        if header.contains("week") { return 70 }
        
        return 100 // Default
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    @MainActor
    private func loadCSV() async {
        isLoading = true
        
        // Small delay for smooth transition
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        do {
            // Verify file exists
            guard FileManager.default.fileExists(atPath: csvURL.path) else {
                parseError = "File not found: \(csvURL.lastPathComponent)"
                isLoading = false
                return
            }
            
            // Read content
            let content = try String(contentsOf: csvURL, encoding: .utf8)
            
            guard !content.isEmpty else {
                parseError = "File is empty"
                isLoading = false
                return
            }
            
            // Parse lines
            let lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
            
            guard let headerLine = lines.first else {
                parseError = "CSV file has no header row"
                isLoading = false
                return
            }
            
            // Parse headers
            headers = parseCSVLine(headerLine)
            
            // Count total rows
            totalRowCount = max(0, lines.count - 1)
            
            // Load preview rows
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
                    // Escaped quote
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
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text("No CSV file to preview")
                .font(.headline)
            Text("The export failed before creating the file.")
                .font(.caption)
                .foregroundColor(.secondary)
            Button("Close") {
                showPreview = false
            }
        }
        .padding()
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
