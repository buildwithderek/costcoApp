//
//  MainTabView.swift
//  DoorAuditApp
//
//  Main tab bar navigation with Receipt capture, List, and Export
//  Created: December 2025
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            // Home - Receipt Capture
            NavigationStack {
                ContentView()
            }
            .tabItem {
                Label("Scan", systemImage: CostcoTheme.Icons.camera)
            }
            
            // Receipts List
            NavigationStack {
                ReceiptsListView()
            }
            .tabItem {
                Label("Receipts", systemImage: CostcoTheme.Icons.list)
            }
            
            // Export
            NavigationStack {
                ExportAuditsView()
            }
            .tabItem {
                Label("Export", systemImage: CostcoTheme.Icons.export)
            }
        }
        .tint(CostcoTheme.Colors.primary)
    }
}

// MARK: - Receipts List View

struct ReceiptsListView: View {
    @State private var viewModel: ReceiptListViewModel
    
    init() {
        _viewModel = State(initialValue: DependencyContainer.shared.makeReceiptListViewModel())
    }
    
    var body: some View {
        Group {
            if viewModel.displayReceipts.isEmpty {
                emptyState
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(CostcoTheme.Colors.background)
            } else {
                List {
                    Section {
                        summaryCard
                            .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 8, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                    }

                    Section(viewModel.resultCount == 1 ? "1 receipt" : "\(viewModel.resultCount) receipts") {
                        ForEach(viewModel.displayReceipts) { receipt in
                            NavigationLink {
                                AuditFormView(receipt: receipt)
                            } label: {
                                ReceiptListRow(receipt: receipt)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    Task {
                                        await viewModel.delete(receipt)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .background(CostcoTheme.Colors.background)
            }
        }
        .background(CostcoTheme.Colors.background)
        .navigationTitle("Receipts")
        .searchable(text: $viewModel.searchQuery, prompt: "Search receipts")
        .safeAreaInset(edge: .top) {
            filterPicker
                .padding(.horizontal, CostcoTheme.Spacing.md)
                .padding(.top, CostcoTheme.Spacing.sm)
                .padding(.bottom, CostcoTheme.Spacing.xs)
                .background(CostcoTheme.Colors.background)
        }
        .task {
            await viewModel.loadReceipts()
        }
        .refreshable {
            await viewModel.refresh()
        }
        .onAppear {
            // Refresh when returning from AuditFormView
            Task {
                await viewModel.refresh()
            }
        }
        .loading(viewModel.isLoading)
        .errorAlert(error: Binding(
            get: { viewModel.error },
            set: { _ in viewModel.clearError() }
        ))
    }
    
    private var filterPicker: some View {
        Picker("Filter", selection: $viewModel.selectedFilter) {
            ForEach(ReceiptListViewModel.FilterOption.allCases, id: \.self) { filter in
                Text(filter.displayName)
                    .tag(filter)
            }
        }
        .pickerStyle(.segmented)
    }
    
    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Review queue")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            Text(viewModel.resultsSummary)
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)

            if viewModel.isSearching {
                Button("Clear Search") {
                    viewModel.searchQuery = ""
                }
                .font(CostcoTheme.Typography.subheadline.weight(.semibold))
                .foregroundColor(CostcoTheme.Colors.primary)
            }
        }
        .costcoCard()
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label(viewModel.emptyStateTitle, systemImage: viewModel.isSearching ? "magnifyingglass" : "doc.text")
        } description: {
            Text(viewModel.emptyStateMessage)
        } actions: {
            if viewModel.isSearching {
                Button("Clear Search") {
                    viewModel.searchQuery = ""
                }
            }
        }
    }
}

// MARK: - Receipt List Row

struct ReceiptListRow: View {
    let receipt: Receipt
    @Environment(\.dependencies) private var dependencies
    @State private var auditStatus: AuditStatusIndicator = .pending
    
    enum AuditStatusIndicator {
        case pending
        case completed
        case hasIssues
        
        var color: Color {
            switch self {
            case .pending: return CostcoTheme.Colors.warning
            case .completed: return CostcoTheme.Colors.success
            case .hasIssues: return CostcoTheme.Colors.secondary
            }
        }
        
        var iconName: String {
            switch self {
            case .pending: return "clock.fill"
            case .completed: return "checkmark.circle.fill"
            case .hasIssues: return "exclamationmark.triangle.fill"
            }
        }
        
        var label: String {
            switch self {
            case .pending: return "Pending"
            case .completed: return "Audited"
            case .hasIssues: return "Issues"
            }
        }
    }
    
    var body: some View {
        HStack(spacing: CostcoTheme.Spacing.md) {
            // Status indicator
            Image(systemName: auditStatus.iconName)
                .font(.caption)
                .foregroundColor(auditStatus.color)
            
            // Receipt info
            VStack(alignment: .leading, spacing: CostcoTheme.Spacing.xs) {
                Text(receipt.shortDescription)
                    .font(CostcoTheme.Typography.headline)
                    .foregroundColor(CostcoTheme.Colors.textPrimary)
                
                HStack(spacing: 4) {
                    Text(receipt.displayTime)
                        .font(CostcoTheme.Typography.caption)
                        .foregroundColor(CostcoTheme.Colors.textSecondary)
                    
                    if !receipt.lineItems.isEmpty {
                        Text("•")
                            .foregroundColor(CostcoTheme.Colors.textSecondary)
                        Text("\(receipt.lineItems.count) items")
                            .font(CostcoTheme.Typography.caption)
                            .foregroundColor(CostcoTheme.Colors.textSecondary)
                    }
                }
                
                // Audit status badge
                Text(auditStatus.label)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(auditStatus.color)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(auditStatus.color.opacity(0.15))
                    .cornerRadius(4)
            }
            
            Spacer()
            
            // Total
            if let total = receipt.totalAmount {
                Text(String(format: "$%.2f", total))
                    .font(CostcoTheme.Typography.priceAmount)
                    .foregroundColor(CostcoTheme.Colors.secondary)
            }
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .padding(CostcoTheme.Spacing.md)
        .background(CostcoTheme.Colors.cardBackground)
        .cornerRadius(CostcoTheme.CornerRadius.card)
        .shadow(
            color: CostcoTheme.Shadow.sm.color,
            radius: CostcoTheme.Shadow.sm.radius,
            x: CostcoTheme.Shadow.sm.x,
            y: CostcoTheme.Shadow.sm.y
        )
        .task {
            await loadAuditStatus()
        }
    }
    
    private func loadAuditStatus() async {
        do {
            if let audit = try await dependencies.auditRepository.fetchAudit(for: receipt.id) {
                await MainActor.run {
                    if audit.hasIssues {
                        auditStatus = .hasIssues
                    } else if !audit.staffName.isEmpty {
                        auditStatus = .completed
                    } else {
                        auditStatus = .pending
                    }
                }
            }
        } catch {
            // Keep as pending if fetch fails
            Logger.shared.debug("Could not load audit status for receipt \(receipt.id)")
        }
    }
}

// MARK: - Preview

#Preview {
    MainTabView()
        .environment(\.dependencies, DependencyContainer.shared)
}
