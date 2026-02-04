//
//  ExportAuditsView.swift
//  DoorAuditApp
//
//  View for exporting audits
//  Created: December 2025
//

import SwiftUI

struct ExportAuditsView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ExportViewModel
    
    init() {
        _viewModel = State(initialValue: DependencyContainer.shared.makeExportViewModel())
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: CostcoTheme.Spacing.lg) {
                // Header
                headerSection
                
                // Date Picker
                datePickerSection
                
                // Format Selection
                formatSection
                
                // Preview
                previewSection
                
                // Export Button
                exportButton
            }
            .padding()
        }
        .background(CostcoTheme.Colors.background)
        .navigationTitle("Export Audits")
        .task {
            await viewModel.loadReceiptsForDate()
        }
        .loading(viewModel.isExporting)
        .errorAlert(error: Binding(
            get: { viewModel.error },
            set: { _ in viewModel.clearError() }
        ))
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let url = viewModel.exportURL {
                ShareSheet(activityItems: [url])
            }
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: CostcoTheme.Spacing.sm) {
            Text("Export Audit Data")
                .font(CostcoTheme.Typography.title2)
                .foregroundColor(CostcoTheme.Colors.textPrimary)
            
            Text(viewModel.exportSummary)
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .padding(.top, CostcoTheme.Spacing.md)
    }
    
    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Select Date")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)
            
            DatePicker(
                "Date",
                selection: $viewModel.selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .onChange(of: viewModel.selectedDate) { oldValue, newValue in
                Task {
                    await viewModel.changeDate(newValue)
                }
            }
        }
        .costcoCard()
    }
    
    private var formatSection: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Export Format")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)
            
            Picker("Format", selection: $viewModel.exportFormat) {
                ForEach(ExportViewModel.UIExportFormat.allCases, id: \.self) { format in
                    Text(format.displayName)
                        .tag(format)
                }
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.exportFormat) { oldValue, newValue in
                viewModel.changeFormat(newValue)
            }
            
            if viewModel.exportFormat == .csv {
                Toggle("Include Images", isOn: $viewModel.includeImages)
                    .onChange(of: viewModel.includeImages) { oldValue, newValue in
                        viewModel.toggleImages()
                    }
            }
        }
        .costcoCard()
    }
    
    private var previewSection: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Preview")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)
            
            if viewModel.receiptsToExport.isEmpty {
                Text("No receipts for selected date")
                    .font(CostcoTheme.Typography.subheadline)
                    .foregroundColor(CostcoTheme.Colors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                ScrollView {
                    Text(viewModel.previewCSV)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(CostcoTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 200)
                .background(CostcoTheme.Colors.cardBackground)
                .cornerRadius(CostcoTheme.CornerRadius.sm)
            }
        }
        .costcoCard()
    }
    
    private var exportButton: some View {
        Button {
            Task {
                await viewModel.export()
            }
        } label: {
            HStack {
                Image(systemName: CostcoTheme.Icons.export)
                    .font(.title2)
                Text("Export")
                    .font(CostcoTheme.Typography.headline)
            }
            .costcoPrimaryButton()
        }
        .disabled(!viewModel.canExport || viewModel.isExporting)
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ExportAuditsView()
            .environment(\.dependencies, DependencyContainer.shared)
    }
}

