//
//  ContentView.swift
//  DoorAuditApp
//
//  Main content view for receipt capture and audit
//  ENHANCED: Uses ReceiptCameraView with real-time detection
//  Auto-navigates to AuditFormView after capture
//  Includes Export button for daily audits
//  Created: December 2025
//

import SwiftUI
import PhotosUI
import AVFoundation

struct ContentView: View {
    @Environment(\.dependencies) private var dependencies
    @State private var viewModel: ReceiptCaptureViewModel
    
    // Camera/Image Picker State
    @State private var showCamera = false
    @State private var showImagePicker = false
    @State private var selectedImage: UIImage?
    
    // Export State
    @State private var showExportView = false
    
    // Navigation
    @State private var navigationPath = NavigationPath()
    
    init() {
        _viewModel = State(initialValue: DependencyContainer.shared.makeReceiptCaptureViewModel())
    }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            mainContent(viewModel: viewModel)
                .navigationDestination(for: Receipt.self) { receipt in
                    AuditFormView(receipt: receipt)
                }
        }
        // Custom Camera with Receipt Detection
        .fullScreenCover(isPresented: $showCamera) {
            ReceiptCameraView(
                onPhotoCaptured: { image in
                    showCamera = false
                    Task {
                        await viewModel.captureReceipt(image)
                    }
                },
                onCancel: {
                    showCamera = false
                }
            )
        }
        // Photo Library Picker
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(
                sourceType: .photoLibrary,
                selectedImage: $selectedImage
            )
        }
        // Export View
        .sheet(isPresented: $showExportView) {
            ExportView()
        }
        .onChange(of: selectedImage) { oldValue, newValue in
            if let image = newValue {
                Task {
                    await viewModel.captureReceipt(image)
                }
                selectedImage = nil
            }
        }
        // Auto-navigate after capture
        .onChange(of: viewModel.shouldNavigateToAudit) { oldValue, newValue in
            if newValue, let receipt = viewModel.capturedReceipt {
                navigationPath.append(receipt)
                viewModel.didNavigateToAudit()
            }
        }
        // Refresh when navigation path changes (returning from child views)
        .onChange(of: navigationPath) { oldValue, newValue in
            // Refresh when navigating back (path gets shorter)
            if newValue.count < oldValue.count {
                Task {
                    await viewModel.loadTodaysReceipts()
                }
            }
        }
        .task {
            await viewModel.loadTodaysReceipts()
        }
        .onAppear {
            // Refresh when returning from AuditFormView
            Task {
                await viewModel.loadTodaysReceipts()
            }
        }
        // Listen for receipt changes from other views (e.g., ReceiptsListView)
        .onReceive(NotificationCenter.default.publisher(for: .receiptsDidChange)) { _ in
            Task {
                await viewModel.loadTodaysReceipts()
            }
        }
    }
    
    @ViewBuilder
    private func mainContent(viewModel: ReceiptCaptureViewModel) -> some View {
        ScrollView {
            VStack(spacing: CostcoTheme.Spacing.lg) {
                // Header
                headerSection
                
                // Stats Cards
                statsSection(viewModel: viewModel)
                
                // Capture Button
                captureButtonSection
                    .padding(.horizontal, CostcoTheme.Spacing.md)
                
                // Today's Receipts
                if !viewModel.todaysReceipts.isEmpty {
                    todaysReceiptsSection(viewModel: viewModel)
                } else {
                    emptyStateSection
                }
            }
            .padding(.vertical, CostcoTheme.Spacing.md)
        }
        .background(CostcoTheme.Colors.background)
        .navigationTitle("Door Audit")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showExportView = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .loading(viewModel.isProcessing)
        .errorAlert(error: Binding(
            get: { viewModel.error },
            set: { _ in viewModel.clearError() }
        ))
    }
    
    private var headerSection: some View {
        VStack(spacing: CostcoTheme.Spacing.sm) {
            Text(AppConstants.Store.fullName)
                .font(CostcoTheme.Typography.title2)
                .foregroundColor(CostcoTheme.Colors.textPrimary)
            
            Text(DateFormatterService.shared.string(from: Date(), type: .display))
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .padding(.top, CostcoTheme.Spacing.md)
    }
    
    @ViewBuilder
    private func statsSection(viewModel: ReceiptCaptureViewModel) -> some View {
        HStack(spacing: CostcoTheme.Spacing.md) {
            StatCard(
                title: "Today",
                value: "\(viewModel.todaysReceipts.count)",
                color: CostcoTheme.Colors.primary
            )
            
            StatCard(
                title: "Total",
                value: "\(viewModel.allReceiptsCount)",
                color: CostcoTheme.Colors.secondary
            )
            
            if !viewModel.todaysReceipts.isEmpty {
                let auditedCount = viewModel.completedCount
                StatCard(
                    title: "Audited",
                    value: "\(auditedCount)/\(viewModel.todaysReceipts.count)",
                    color: auditedCount == viewModel.todaysReceipts.count
                        ? CostcoTheme.Colors.success
                        : CostcoTheme.Colors.warning
                )
            }
        }
        .padding(.horizontal, CostcoTheme.Spacing.md)
    }
    
    private var captureButtonSection: some View {
        VStack(spacing: CostcoTheme.Spacing.md) {
            // Primary: Camera with receipt detection
            Button {
                handleScanTap()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "camera.viewfinder")
                        .font(.title2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scan Receipt")
                            .font(CostcoTheme.Typography.headline)
                        Text("Auto-detect & crop")
                            .font(CostcoTheme.Typography.caption)
                            .opacity(0.8)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .opacity(0.6)
                }
                .costcoPrimaryButton()
            }
            .accessibilityLabel("Scan Receipt with camera")
            .accessibilityHint("Opens camera with real-time receipt detection")
            
            // Secondary buttons row
            HStack(spacing: CostcoTheme.Spacing.md) {
                // Photo library
                Button {
                    showImagePicker = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Library")
                    }
                    .font(CostcoTheme.Typography.subheadline)
                    .foregroundColor(CostcoTheme.Colors.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CostcoTheme.Colors.primary.opacity(0.1))
                    .cornerRadius(CostcoTheme.CornerRadius.button)
                }
                
                // Export button
                Button {
                    showExportView = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(CostcoTheme.Typography.subheadline)
                    .foregroundColor(CostcoTheme.Colors.success)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(CostcoTheme.Colors.success.opacity(0.1))
                    .cornerRadius(CostcoTheme.CornerRadius.button)
                }
            }
        }
    }
    
    private func handleScanTap() {
        // Check if camera is available
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            // Fallback to photo library
            showImagePicker = true
            return
        }
        
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            showCamera = true
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        showCamera = true
                    } else {
                        viewModel.error = CameraError.permissionDenied
                    }
                }
            }
            
        case .denied, .restricted:
            viewModel.error = CameraError.permissionDenied
            
        @unknown default:
            showImagePicker = true
        }
    }
    
    @ViewBuilder
    private func todaysReceiptsSection(viewModel: ReceiptCaptureViewModel) -> some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.md) {
            // Header with View All link
            HStack {
                Text("Receipts Today")
                    .font(CostcoTheme.Typography.title3)
                    .foregroundColor(CostcoTheme.Colors.textPrimary)
                
                Spacer()
                
                if !viewModel.todaysReceipts.isEmpty {
                    NavigationLink {
                        ReceiptsListView()
                    } label: {
                        HStack(spacing: 4) {
                            Text("View All")
                                .font(CostcoTheme.Typography.subheadline)
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundColor(CostcoTheme.Colors.primary)
                    }
                }
            }
            .padding(.horizontal, CostcoTheme.Spacing.md)
            
            // Use List for swipeActions support
            List {
                ForEach(Array(viewModel.todaysReceipts.enumerated()), id: \.element.id) { index, receipt in
                    ReceiptRow(receipt: receipt, receiptNumber: index + 1)
                        .contentShape(Rectangle())
                        .listRowInsets(EdgeInsets(top: 0, leading: CostcoTheme.Spacing.md, bottom: 0, trailing: CostcoTheme.Spacing.md))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task {
                                    await viewModel.deleteReceipt(receipt)
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .onTapGesture {
                            navigationPath.append(receipt)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(height: CGFloat(viewModel.todaysReceipts.count) * 120) // Approximate height per row
        }
    }
    
    private var emptyStateSection: some View {
        VStack(spacing: CostcoTheme.Spacing.md) {
            Image(systemName: "camera.viewfinder")
                .font(.system(size: 48))
                .foregroundColor(CostcoTheme.Colors.textSecondary)
            
            Text("No receipts captured today")
                .font(CostcoTheme.Typography.title3)
                .foregroundColor(CostcoTheme.Colors.textPrimary)
            
            Text("Tap 'Scan Receipt' to get started")
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .padding(CostcoTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: CostcoTheme.Spacing.xs) {
            Text(value)
                .font(CostcoTheme.Typography.title)
                .foregroundColor(color)
            
            Text(title)
                .font(CostcoTheme.Typography.caption)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .costcoCard()
    }
}

struct ReceiptRow: View {
    let receipt: Receipt
    let receiptNumber: Int?
    @Environment(\.dependencies) private var dependencies
    @State private var isPressed = false
    @State private var thumbnailImage: UIImage?
    @State private var auditStatus: AuditStatus = .pending
    
    enum AuditStatus {
        case pending
        case completed
        
        var color: Color {
            switch self {
            case .pending: return CostcoTheme.Colors.warning
            case .completed: return CostcoTheme.Colors.success
            }
        }
        
        var iconName: String {
            switch self {
            case .pending: return "clock.fill"
            case .completed: return "checkmark.circle.fill"
            }
        }
        
        var label: String {
            switch self {
            case .pending: return "Pending"
            case .completed: return "Audited"
            }
        }
    }
    
    init(receipt: Receipt, receiptNumber: Int? = nil) {
        self.receipt = receipt
        self.receiptNumber = receiptNumber
    }
    
    var body: some View {
        HStack(spacing: CostcoTheme.Spacing.md) {
            // Receipt Thumbnail with status overlay
            ZStack(alignment: .topLeading) {
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 80)
                        .clipped()
                        .cornerRadius(CostcoTheme.CornerRadius.sm)
                } else {
                    RoundedRectangle(cornerRadius: CostcoTheme.CornerRadius.sm)
                        .fill(CostcoTheme.Colors.cardBackground)
                        .frame(width: 60, height: 80)
                        .overlay(
                            Image(systemName: "doc.text")
                                .font(.title3)
                                .foregroundColor(CostcoTheme.Colors.textSecondary)
                        )
                }
                
                // Status indicator badge
                Image(systemName: auditStatus.iconName)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .padding(4)
                    .background(auditStatus.color)
                    .clipShape(Circle())
                    .offset(x: -4, y: -4)
            }
            
            // Receipt Info - middle section
            VStack(alignment: .leading, spacing: 4) {
                // Title row: Receipt name + status badge
                HStack(spacing: 8) {
                    if let receiptNumber = receiptNumber {
                        Text(numberToWords(receiptNumber))
                            .font(CostcoTheme.Typography.headline)
                            .foregroundColor(CostcoTheme.Colors.textPrimary)
                            .lineLimit(1)
                    } else if let storeName = receipt.storeName, !storeName.isEmpty {
                        Text(storeName)
                            .font(CostcoTheme.Typography.headline)
                            .foregroundColor(CostcoTheme.Colors.textPrimary)
                            .lineLimit(1)
                    } else {
                        Text(receipt.shortDescription)
                            .font(CostcoTheme.Typography.headline)
                            .foregroundColor(CostcoTheme.Colors.textPrimary)
                            .lineLimit(1)
                    }
                    
                    // Audit status badge - compact
                    Text(auditStatus.label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(auditStatus.color)
                        .cornerRadius(4)
                }
                
                // Transaction details - single line, compact
                Text([
                    receipt.registerNumber.map { "Reg \($0)" },
                    receipt.transactionNumber.map { "#\($0)" },
                    receipt.cashierNumber.map { "Op \($0)" }
                ].compactMap { $0 }.joined(separator: " • "))
                    .font(CostcoTheme.Typography.caption)
                    .foregroundColor(CostcoTheme.Colors.textSecondary)
                    .lineLimit(1)
                
                // Item count
                if !receipt.lineItems.isEmpty {
                    Text("\(receipt.lineItems.count) items")
                        .font(CostcoTheme.Typography.caption)
                        .foregroundColor(CostcoTheme.Colors.textSecondary)
                }
            }
            
            Spacer(minLength: 8)
            
            // Right side: Total + chevron
            VStack(alignment: .trailing, spacing: 4) {
                if let total = receipt.totalAmount {
                    Text("$\(total, specifier: "%.2f")")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(CostcoTheme.Colors.secondary)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(CostcoTheme.Colors.textSecondary)
            }
        }
        .padding(CostcoTheme.Spacing.md)
        .background(CostcoTheme.Colors.cardBackground)
        .cornerRadius(CostcoTheme.CornerRadius.card)
        .shadow(
            color: CostcoTheme.Shadow.md.color,
            radius: CostcoTheme.Shadow.md.radius,
            x: CostcoTheme.Shadow.md.x,
            y: CostcoTheme.Shadow.md.y
        )
        .scaleEffect(isPressed ? 0.98 : 1.0)
        .animation(CostcoTheme.Animation.quick, value: isPressed)
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .task {
            await loadThumbnail()
            await loadAuditStatus()
        }
        .accessibilityLabel("Receipt: \(receipt.shortDescription), \(auditStatus.label)")
        .accessibilityHint("Double tap to audit this receipt")
    }
    
    private func loadThumbnail() async {
        guard let imageID = receipt.imageID else { return }
        let thumbnailSize = CGSize(width: 60, height: 80)
        if let thumbnail = try? await dependencies.imageRepository.fetchThumbnail(id: imageID, size: thumbnailSize) {
            await MainActor.run {
                self.thumbnailImage = thumbnail
            }
        }
    }
    
    private func loadAuditStatus() async {
        do {
            if let audit = try await dependencies.auditRepository.fetchAudit(for: receipt.id) {
                await MainActor.run {
                    // Simple: if staff name is filled, it's completed
                    if !audit.staffName.isEmpty {
                        auditStatus = .completed
                    } else {
                        auditStatus = .pending
                    }
                }
            }
        } catch {
            // Keep as pending if fetch fails
        }
    }
    
    private func numberToWords(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        if let spelledOut = formatter.string(from: NSNumber(value: number)) {
            return "Receipt \(spelledOut.capitalized)"
        }
        return "Receipt \(number)"
    }
}

// MARK: - Image Picker (for Photo Library)

struct ImagePicker: UIViewControllerRepresentable {
    let sourceType: UIImagePickerController.SourceType
    @Binding var selectedImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        picker.mediaTypes = ["public.image"]
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.selectedImage = image
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(\.dependencies, DependencyContainer.shared)
}
