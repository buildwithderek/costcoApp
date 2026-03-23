//
//  ExportAuditsView.swift
//  DoorAuditApp
//
//  View for exporting audits
//  Created: December 2025
//

import SwiftUI

struct ExportAuditsView: View {
    @State private var viewModel: ExportViewModel

    init() {
        _viewModel = State(initialValue: DependencyContainer.shared.makeExportViewModel())
    }

    var body: some View {
        ScrollView {
            VStack(spacing: CostcoTheme.Spacing.lg) {
                headerSection
                summaryCard
                datePickerSection
                formatSection
                previewSection
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
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Export audit data")
                .font(CostcoTheme.Typography.title2)
                .foregroundColor(CostcoTheme.Colors.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Choose a day, confirm the preview, and export a file that is ready to share.")
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, CostcoTheme.Spacing.md)
    }

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Label(viewModel.selectedDateLabel, systemImage: "calendar")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            Text(viewModel.exportSummary)
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)

            Text(viewModel.primaryActionSubtitle)
                .font(CostcoTheme.Typography.caption)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .costcoCard()
    }

    private var datePickerSection: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Select date")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            DatePicker(
                "Date",
                selection: $viewModel.selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .onChange(of: viewModel.selectedDate) { oldValue, newValue in
                Task {
                    await viewModel.changeDate(newValue)
                }
            }

            Text("Switch days to export a different batch of receipts.")
                .font(CostcoTheme.Typography.caption)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .costcoCard()
    }

    private var formatSection: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Export format")
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
                Toggle("Include images", isOn: $viewModel.includeImages)
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
                ContentUnavailableView {
                    Label("No receipts for this date", systemImage: "calendar.badge.exclamationmark")
                } description: {
                    Text("Pick a different date to preview and export completed audits.")
                }
            } else {
                ScrollView {
                    Text(viewModel.previewCSV)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(CostcoTheme.Colors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
                .frame(maxHeight: 220)
                .background(CostcoTheme.Colors.cardBackground)
                .cornerRadius(CostcoTheme.CornerRadius.sm)

                Text(viewModel.previewDescription)
                    .font(CostcoTheme.Typography.caption)
                    .foregroundColor(CostcoTheme.Colors.textSecondary)
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
            HStack(spacing: 12) {
                Image(systemName: CostcoTheme.Icons.export)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.primaryActionTitle)
                        .font(CostcoTheme.Typography.headline)
                    Text(viewModel.primaryActionSubtitle)
                        .font(CostcoTheme.Typography.caption)
                        .opacity(0.85)
                }

                Spacer()
            }
            .costcoPrimaryButton()
        }
        .disabled(!viewModel.canExport || viewModel.isExporting)
        .opacity(viewModel.canExport ? 1 : 0.7)
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
