//
//  ScanReviewView.swift
//  DoorAuditApp
//
//  Editable scan review with draggable receipt corners
//  Created: March 2026
//

import SwiftUI
import UIKit

struct ScanReviewView: View {
    let onAccept: (UIImage) -> Void
    let onRetake: () -> Void

    private let image: UIImage
    private let scannerService: VisionDocumentScannerService
    private let enhancementService: CoreImageEnhancementService
    private let qualityService: CoreImageQualityService
    private let initialDocument: DetectedDocument

    @State private var editableDocument: DetectedDocument
    @State private var selectedEnhancementMode: ScanEnhancementMode
    @State private var qualityFeedback: ScanQualityFeedback?
    private let initialDocument: DetectedDocument

    @State private var editableDocument: DetectedDocument
    @State private var previewImage: UIImage

    init(
        image: UIImage,
        onAccept: @escaping (UIImage) -> Void,
        onRetake: @escaping () -> Void
    ) {
        let fixedImage = image.fixedOrientation()
        let scannerService = VisionDocumentScannerService()
        let enhancementService = CoreImageEnhancementService()
        let qualityService = CoreImageQualityService()
        let detectedDocument = scannerService.detectDocument(in: fixedImage) ?? .defaultDocument()
        let selectedEnhancementMode: ScanEnhancementMode = .receipt
        let correctedPreview = scannerService.correctPerspective(in: fixedImage, using: detectedDocument) ?? fixedImage
        let enhancedPreview = enhancementService.enhance(correctedPreview, mode: selectedEnhancementMode) ?? correctedPreview
        let qualityFeedback = qualityService.analyze(correctedPreview)
        let detectedDocument = scannerService.detectDocument(in: fixedImage) ?? .defaultDocument()
        let correctedPreview = scannerService.correctPerspective(in: fixedImage, using: detectedDocument) ?? fixedImage

        self.image = fixedImage
        self.onAccept = onAccept
        self.onRetake = onRetake
        self.scannerService = scannerService
        self.enhancementService = enhancementService
        self.qualityService = qualityService
        self.initialDocument = detectedDocument
        _editableDocument = State(initialValue: detectedDocument)
        _selectedEnhancementMode = State(initialValue: selectedEnhancementMode)
        _qualityFeedback = State(initialValue: qualityFeedback)
        _previewImage = State(initialValue: enhancedPreview)
        self.initialDocument = detectedDocument
        _editableDocument = State(initialValue: detectedDocument)
        _previewImage = State(initialValue: correctedPreview)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: CostcoTheme.Spacing.md) {
                    instructionsCard
                    editorCard
                    enhancementCard
                    previewCard
                    qualityCard
                    previewCard
                }
                .padding(CostcoTheme.Spacing.md)
            }
            .background(CostcoTheme.Colors.background)
            .navigationTitle("Adjust Scan")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                actionBar
            }
        }
    }

    private var instructionsCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Label("Adjust the corners to match the receipt edges.", systemImage: "viewfinder")
                .font(CostcoTheme.Typography.headline)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            Text("The corrected scan updates as you drag each handle, and you can switch enhancement presets to make thermal receipt text easier to read before OCR runs.")
            Text("The corrected scan updates as you drag each handle, so you can rescue skewed or off-angle captures before OCR runs.")
                .font(CostcoTheme.Typography.subheadline)
                .foregroundColor(CostcoTheme.Colors.textSecondary)

            if initialDocument.confidence > 0 {
                Text("Auto-detected receipt bounds")
                    .font(CostcoTheme.Typography.caption)
                    .foregroundColor(CostcoTheme.Colors.success)
            } else {
                Text("No receipt bounds found automatically — starting with a default frame.")
                    .font(CostcoTheme.Typography.caption)
                    .foregroundColor(CostcoTheme.Colors.warning)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .costcoCard()
    }

    private var editorCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            HStack {
                Text("Corner editor")
                    .font(CostcoTheme.Typography.title3)
                    .foregroundColor(CostcoTheme.Colors.textPrimary)

                Spacer()

                Button("Reset") {
                    editableDocument = initialDocument
                    refreshPreview()
                }
                .font(CostcoTheme.Typography.subheadline.weight(.semibold))
                .foregroundColor(CostcoTheme.Colors.primary)
            }

            GeometryReader { geometry in
                let imageRect = aspectFitRect(for: image.size, in: geometry.size)

                ZStack {
                    RoundedRectangle(cornerRadius: CostcoTheme.CornerRadius.card)
                        .fill(Color.black)

                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: imageRect.width, height: imageRect.height)
                        .position(x: imageRect.midX, y: imageRect.midY)

                    QuadrilateralOverlayShape(
                        topLeft: displayPoint(for: editableDocument.topLeft, in: imageRect),
                        topRight: displayPoint(for: editableDocument.topRight, in: imageRect),
                        bottomRight: displayPoint(for: editableDocument.bottomRight, in: imageRect),
                        bottomLeft: displayPoint(for: editableDocument.bottomLeft, in: imageRect)
                    )
                    .stroke(CostcoTheme.Colors.secondary, style: StrokeStyle(lineWidth: 3, lineJoin: .round))

                    ForEach(DocumentCorner.allCases) { corner in
                        CornerHandle(
                            position: displayPoint(for: editableDocument.point(for: corner), in: imageRect),
                            accentColor: handleColor(for: corner)
                        )
                        .gesture(
                            DragGesture(minimumDistance: 0, coordinateSpace: .named("scan-editor"))
                                .onChanged { value in
                                    updateCorner(
                                        corner,
                                        with: value.location,
                                        imageRect: imageRect
                                    )
                                }
                        )
                    }
                }
                .coordinateSpace(name: "scan-editor")
            }
            .frame(height: 420)
            .clipShape(RoundedRectangle(cornerRadius: CostcoTheme.CornerRadius.card))

            Text("Tip: line up each handle with the printed receipt corners for the cleanest flattening.")
                .font(CostcoTheme.Typography.footnote)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .costcoCard()
    }

    private var enhancementCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Enhancement modes")
                .font(CostcoTheme.Typography.title3)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            Text("Pick the version that makes totals, line items, and thermal-print text easiest to read.")
                .font(CostcoTheme.Typography.footnote)
                .foregroundColor(CostcoTheme.Colors.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: CostcoTheme.Spacing.sm) {
                    ForEach(ScanEnhancementMode.allCases) { mode in
                        enhancementButton(for: mode)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .costcoCard()
    }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            HStack {
                Text("Corrected preview")
                    .font(CostcoTheme.Typography.title3)
                    .foregroundColor(CostcoTheme.Colors.textPrimary)

                Spacer()

                Text(selectedEnhancementMode.title)
                    .font(CostcoTheme.Typography.caption.weight(.semibold))
                    .foregroundColor(CostcoTheme.Colors.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(CostcoTheme.Colors.primary.opacity(0.12))
                    .clipShape(Capsule())
            }

    private var previewCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Corrected preview")
                .font(CostcoTheme.Typography.title3)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            Image(uiImage: previewImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 260)
                .background(
                    RoundedRectangle(cornerRadius: CostcoTheme.CornerRadius.md)
                        .fill(Color.black)
                )
                .clipShape(RoundedRectangle(cornerRadius: CostcoTheme.CornerRadius.md))

            Text("This flattened and enhanced image is what gets passed into the OCR and receipt-processing pipeline.")
            Text("This flattened image is what gets passed into the OCR and receipt-processing pipeline.")
                .font(CostcoTheme.Typography.footnote)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .costcoCard()
    }

    private var actionBar: some View {
        VStack(spacing: CostcoTheme.Spacing.sm) {
            Divider()

            HStack(spacing: CostcoTheme.Spacing.md) {
                Button {
                    onRetake()
                } label: {
                    Label("Retake", systemImage: "arrow.counterclockwise")
                        .costcoSecondaryButton()
                }

                Button {
                    onAccept(previewImage)
                } label: {
                    Label("Use Scan", systemImage: "checkmark")
                        .costcoPrimaryButton()
                }
            }
            .padding(.horizontal, CostcoTheme.Spacing.md)
            .padding(.bottom, CostcoTheme.Spacing.sm)
            .background(CostcoTheme.Colors.cardBackground)
        }
        .background(CostcoTheme.Colors.cardBackground)
    }

    private var qualityCard: some View {
        VStack(alignment: .leading, spacing: CostcoTheme.Spacing.sm) {
            Text("Scan quality")
                .font(CostcoTheme.Typography.title3)
                .foregroundColor(CostcoTheme.Colors.textPrimary)

            if let qualityFeedback {
                HStack(spacing: CostcoTheme.Spacing.sm) {
                    qualityMetricChip(
                        title: "Brightness",
                        value: "\(Int(qualityFeedback.brightnessScore * 100))%"
                    )

                    qualityMetricChip(
                        title: "Edge detail",
                        value: String(format: "%.2f", qualityFeedback.sharpnessScore)
                    )
                }

                Label(
                    qualityFeedback.shouldRetake ? "Retake recommended" : "Ready for OCR",
                    systemImage: qualityFeedback.shouldRetake ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"
                )
                .font(CostcoTheme.Typography.subheadline.weight(.semibold))
                .foregroundColor(
                    qualityFeedback.shouldRetake
                        ? CostcoTheme.Colors.warning
                        : CostcoTheme.Colors.success
                )

                Text(qualityFeedback.summary)
                    .font(CostcoTheme.Typography.subheadline)
                    .foregroundColor(CostcoTheme.Colors.textSecondary)

                if qualityFeedback.shouldRetake {
                    Text("You can still continue, but OCR may miss totals or line items if the image stays dark or blurry.")
                        .font(CostcoTheme.Typography.footnote)
                        .foregroundColor(CostcoTheme.Colors.warning)
                }
            } else {
                Text("Quality analysis is unavailable for this preview.")
                    .font(CostcoTheme.Typography.subheadline)
                    .foregroundColor(CostcoTheme.Colors.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .costcoCard()
    }

    @ViewBuilder
    private func qualityMetricChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(CostcoTheme.Typography.caption)
                .foregroundColor(CostcoTheme.Colors.textSecondary)
            Text(value)
                .font(CostcoTheme.Typography.subheadline.weight(.semibold))
                .foregroundColor(CostcoTheme.Colors.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(CostcoTheme.Colors.primary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: CostcoTheme.CornerRadius.md))
    }

    @ViewBuilder
    private func enhancementButton(for mode: ScanEnhancementMode) -> some View {
        let isSelected = selectedEnhancementMode == mode

        Button {
            selectedEnhancementMode = mode
            refreshPreview()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(mode.title)
                    .font(CostcoTheme.Typography.subheadline.weight(.semibold))
                Text(mode.subtitle)
                    .font(CostcoTheme.Typography.caption)
            }
            .foregroundColor(isSelected ? .white : CostcoTheme.Colors.textPrimary)
            .frame(width: 124, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: CostcoTheme.CornerRadius.md)
                    .fill(isSelected ? CostcoTheme.Colors.primary : CostcoTheme.Colors.primary.opacity(0.08))
            )
        }
        .buttonStyle(.plain)
    }

    private func handleColor(for corner: DocumentCorner) -> Color {
        switch corner {
        case .topLeft, .bottomRight:
            CostcoTheme.Colors.secondary
        case .topRight, .bottomLeft:
            CostcoTheme.Colors.primary
        }
    }

    private func updateCorner(_ corner: DocumentCorner, with location: CGPoint, imageRect: CGRect) {
        let normalizedPoint = normalizedPoint(from: location, in: imageRect)
        editableDocument = editableDocument.updating(corner, to: normalizedPoint)
        refreshPreview()
    }

    private func refreshPreview() {
        let correctedImage = scannerService.correctPerspective(in: image, using: editableDocument) ?? image
        qualityFeedback = qualityService.analyze(correctedImage)
        previewImage = enhancementService.enhance(correctedImage, mode: selectedEnhancementMode) ?? correctedImage
        previewImage = scannerService.correctPerspective(in: image, using: editableDocument) ?? image
    }

    private func displayPoint(for normalizedPoint: CGPoint, in imageRect: CGRect) -> CGPoint {
        CGPoint(
            x: imageRect.minX + (normalizedPoint.x * imageRect.width),
            y: imageRect.maxY - (normalizedPoint.y * imageRect.height)
        )
    }

    private func normalizedPoint(from displayPoint: CGPoint, in imageRect: CGRect) -> CGPoint {
        let clampedX = min(max(displayPoint.x, imageRect.minX), imageRect.maxX)
        let clampedY = min(max(displayPoint.y, imageRect.minY), imageRect.maxY)

        let normalizedX = (clampedX - imageRect.minX) / imageRect.width
        let normalizedY = (imageRect.maxY - clampedY) / imageRect.height

        return CGPoint(
            x: min(max(normalizedX, 0), 1),
            y: min(max(normalizedY, 0), 1)
        )
    }

    private func aspectFitRect(for imageSize: CGSize, in containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0,
              containerSize.width > 0, containerSize.height > 0 else {
            return .zero
        }

        let imageAspect = imageSize.width / imageSize.height
        let containerAspect = containerSize.width / containerSize.height

        let fittedSize: CGSize
        if imageAspect > containerAspect {
            fittedSize = CGSize(
                width: containerSize.width,
                height: containerSize.width / imageAspect
            )
        } else {
            fittedSize = CGSize(
                width: containerSize.height * imageAspect,
                height: containerSize.height
            )
        }

        return CGRect(
            x: (containerSize.width - fittedSize.width) / 2,
            y: (containerSize.height - fittedSize.height) / 2,
            width: fittedSize.width,
            height: fittedSize.height
        )
    }
}

private struct CornerHandle: View {
    let position: CGPoint
    let accentColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 28, height: 28)

            Circle()
                .stroke(accentColor, lineWidth: 4)
                .frame(width: 28, height: 28)

            Circle()
                .fill(accentColor)
                .frame(width: 10, height: 10)
        }
        .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
        .position(position)
    }
}

private struct QuadrilateralOverlayShape: Shape {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomRight: CGPoint
    let bottomLeft: CGPoint

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: topLeft)
        path.addLine(to: topRight)
        path.addLine(to: bottomRight)
        path.addLine(to: bottomLeft)
        path.closeSubpath()
        return path
    }
}

#Preview {
    ScanReviewView(
        image: UIImage(systemName: "doc.text.viewfinder") ?? UIImage(),
        onAccept: { _ in },
        onRetake: {}
    )
}
