//
//  ReceiptCameraView.swift
//  DoorAuditApp
//
//  Camera view with real-time receipt detection
//  Uses Vision framework for rectangle detection
//  Created: December 2025
//

import SwiftUI
import AVFoundation
import Vision

struct ReceiptCameraView: View {
    let onPhotoCaptured: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var capturedImage: UIImage?
    @State private var showReview = false
    @State private var captureTrigger = 0
    @State private var isCapturing = false
    @State private var scannerGuidance: ScannerGuidanceState = .searching

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(
                captureTrigger: captureTrigger,
                onCaptureStarted: { isAutomatic in
                    isCapturing = true
                    scannerGuidance = isAutomatic ? .autoCapturing : .manualCaptureInProgress
                },
                onCapture: { image in
                    capturedImage = image
                    isCapturing = false
                    showReview = true
                },
                onGuidanceChanged: { guidance in
                    guard !isCapturing else { return }
                    scannerGuidance = guidance
                }
            )

            // Overlay
            VStack(spacing: 0) {
                topBar

                Spacer()

                guideFrame

                Spacer()

                captureControls
            }
            .padding()
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showReview) {
            if let image = capturedImage {
                ScanReviewView(
                    image: image,
                    onAccept: { correctedImage in
                        showReview = false
                        onPhotoCaptured(correctedImage)
                    },
                    onRetake: {
                        showReview = false
                        capturedImage = nil
                        isCapturing = false
                    }
                )
            }
        }
    }

    private var topBar: some View {
        HStack(alignment: .top) {
            Button {
                onCancel()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Circle())
            }
            .accessibilityLabel("Close camera")

            Spacer()

            VStack(spacing: 8) {
                Text("Scan receipt")
                    .font(.headline.weight(.semibold))
                    .foregroundColor(.white)

                Text("Align the full receipt inside the frame, then tap the shutter.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.black.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: 260)

            Spacer()

            Circle()
                .fill(Color.clear)
                .frame(width: 44, height: 44)
        }
        .padding(.top, 12)
    }

    private var guideFrame: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(Color.white.opacity(0.85), lineWidth: 3)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.black.opacity(0.08))
            )
            .frame(width: 280, height: 400)
            .overlay(alignment: .top) {
                Label("Fit all edges", systemImage: "viewfinder")
                    .font(.caption.weight(.medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.55))
                    .clipShape(Capsule())
                    .padding(.top, 12)
            }
    }

    private var captureControls: some View {
        VStack(spacing: 16) {
            if isCapturing {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(.white)
                    Text("Capturing photo…")
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color.black.opacity(0.55))
                .clipShape(Capsule())
            } else {
                Text(scannerGuidance.message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }

            Button {
                captureTrigger += 1
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.28))
                        .frame(width: 84, height: 84)

                    Circle()
                        .fill(Color.white)
                        .frame(width: 66, height: 66)
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )
                }
            }
            .buttonStyle(.plain)
            .disabled(isCapturing)
            .accessibilityLabel("Capture receipt")
            .accessibilityHint("Takes a photo of the receipt inside the guide frame")

            Text("Need a better shot? You can retake before saving, or tap the shutter anytime to override auto-capture.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }
}

enum ScannerGuidanceState: Equatable {
    case searching
    case moveCloser
    case holdSteady(progress: Int, total: Int)
    case readyToCapture
    case autoCapturing
    case manualCaptureInProgress

    var message: String {
        switch self {
        case .searching:
            return "Find the full receipt to start live detection."
        case .moveCloser:
            return "Move closer so the receipt fills more of the frame."
        case .holdSteady(let progress, let total):
            return "Hold steady… \(min(progress, total))/\(total)"
        case .readyToCapture:
            return "Receipt locked — capturing automatically."
        case .autoCapturing:
            return "Auto-capturing receipt…"
        case .manualCaptureInProgress:
            return "Capturing photo…"
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewControllerRepresentable {
    let captureTrigger: Int
    let onCaptureStarted: (Bool) -> Void
    let onCapture: (UIImage) -> Void
    let onGuidanceChanged: (ScannerGuidanceState) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCaptureStarted = onCaptureStarted
        controller.onCapture = onCapture
        controller.onGuidanceChanged = onGuidanceChanged
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if context.coordinator.lastCaptureTrigger != captureTrigger {
            context.coordinator.lastCaptureTrigger = captureTrigger
            uiViewController.capturePhoto(triggeredAutomatically: false)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(lastCaptureTrigger: captureTrigger)
    }

    final class Coordinator {
        var lastCaptureTrigger: Int

        init(lastCaptureTrigger: Int) {
            self.lastCaptureTrigger = lastCaptureTrigger
        }
    }
}

// MARK: - Camera View Controller

class CameraViewController: UIViewController {
    var onCaptureStarted: ((Bool) -> Void)?
    var onCapture: ((UIImage) -> Void)?
    var onGuidanceChanged: ((ScannerGuidanceState) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let detectionQueue = DispatchQueue(label: "com.costcoapp.camera.detection", qos: .userInitiated)
    private let documentScannerService = VisionDocumentScannerService()
    private let documentOverlayLayer = CAShapeLayer()
    private var isCaptureInProgress = false
    private var stableFrameCount = 0
    private var lastDetectedCenter: CGPoint?
    private var lastDetectedArea: CGFloat = 0
    private var lastAnalysisTimestamp: CFTimeInterval = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupOverlay()
        publishGuidance(.searching)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        startSession()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            Logger.shared.error("Failed to setup camera input")
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        }

        let output = AVCapturePhotoOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.alwaysDiscardsLateVideoFrames = true
        videoOutput.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
        ]
        videoOutput.setSampleBufferDelegate(self, queue: detectionQueue)
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        self.captureSession = session
        self.previewLayer = previewLayer
        self.photoOutput = output
        self.videoOutput = videoOutput

        if let photoConnection = output.connection(with: .video) {
            photoConnection.videoOrientation = .portrait
        }

        if let videoConnection = videoOutput.connection(with: .video) {
            videoConnection.videoOrientation = .portrait
        }
    }

    private func setupOverlay() {
        documentOverlayLayer.strokeColor = UIColor.systemYellow.cgColor
        documentOverlayLayer.fillColor = UIColor.clear.cgColor
        documentOverlayLayer.lineWidth = 3
        documentOverlayLayer.lineJoin = .round
        documentOverlayLayer.frame = view.bounds
        view.layer.addSublayer(documentOverlayLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        documentOverlayLayer.frame = view.bounds
    }

    private func startSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    func capturePhoto(triggeredAutomatically: Bool) {
        guard !isCaptureInProgress, let photoOutput = photoOutput else { return }

        isCaptureInProgress = true
        stableFrameCount = 0
        lastDetectedCenter = nil
        lastDetectedArea = 0
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        publishGuidance(triggeredAutomatically ? .autoCapturing : .manualCaptureInProgress)
        onCaptureStarted?(triggeredAutomatically)

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    private func handleLiveDetectionResult(_ document: DetectedDocument?) {
        guard !isCaptureInProgress else { return }

        guard let document else {
            stableFrameCount = 0
            lastDetectedCenter = nil
            lastDetectedArea = 0
            updateOverlay(with: nil)
            publishGuidance(.searching)
            return
        }

        updateOverlay(with: document)

        guard document.area >= AppConstants.ImageProcessing.minLiveDocumentArea else {
            stableFrameCount = 0
            lastDetectedCenter = document.center
            lastDetectedArea = document.area
            publishGuidance(.moveCloser)
            return
        }

        let isStable: Bool
        if let lastDetectedCenter {
            let xDelta = abs(document.center.x - lastDetectedCenter.x)
            let yDelta = abs(document.center.y - lastDetectedCenter.y)
            let areaDelta = abs(document.area - lastDetectedArea)
            isStable = xDelta < 0.03 && yDelta < 0.03 && areaDelta < 0.04
        } else {
            isStable = false
        }

        stableFrameCount = isStable ? (stableFrameCount + 1) : 1
        lastDetectedCenter = document.center
        lastDetectedArea = document.area

        if stableFrameCount >= AppConstants.ImageProcessing.stableFrameThreshold {
            publishGuidance(.readyToCapture)
            DispatchQueue.main.async { [weak self] in
                self?.capturePhoto(triggeredAutomatically: true)
            }
        } else {
            publishGuidance(
                .holdSteady(
                    progress: stableFrameCount,
                    total: AppConstants.ImageProcessing.stableFrameThreshold
                )
            )
        }
    }

    private func updateOverlay(with document: DetectedDocument?) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            guard let previewLayer = self.previewLayer,
                  let document else {
                self.documentOverlayLayer.path = nil
                return
            }

            let topLeft = self.layerPoint(for: document.topLeft, previewLayer: previewLayer)
            let topRight = self.layerPoint(for: document.topRight, previewLayer: previewLayer)
            let bottomRight = self.layerPoint(for: document.bottomRight, previewLayer: previewLayer)
            let bottomLeft = self.layerPoint(for: document.bottomLeft, previewLayer: previewLayer)

            let path = UIBezierPath()
            path.move(to: topLeft)
            path.addLine(to: topRight)
            path.addLine(to: bottomRight)
            path.addLine(to: bottomLeft)
            path.close()

            self.documentOverlayLayer.path = path.cgPath
        }
    }

    private func layerPoint(for normalizedPoint: CGPoint, previewLayer: AVCaptureVideoPreviewLayer) -> CGPoint {
        previewLayer.layerPointConverted(
            fromCaptureDevicePoint: CGPoint(
                x: normalizedPoint.x,
                y: 1 - normalizedPoint.y
            )
        )
    }

    private func publishGuidance(_ guidance: ScannerGuidanceState) {
        DispatchQueue.main.async { [weak self] in
            self?.onGuidanceChanged?(guidance)
        }
    }
}

// MARK: - Photo Capture Delegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer { isCaptureInProgress = false }

        if let error = error {
            Logger.shared.error("Photo capture failed", error: error)
            return
        }

        guard let imageData = photo.fileDataRepresentation(),
              let image = UIImage(data: imageData) else {
            Logger.shared.error("Failed to create image from photo data")
            return
        }

        DispatchQueue.main.async { [weak self] in
            self?.documentOverlayLayer.path = nil
            self?.publishGuidance(.searching)
            self?.onCapture?(image)
        }
    }
}

// MARK: - Live Video Detection Delegate

extension CameraViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard !isCaptureInProgress,
              CMSampleBufferDataIsReady(sampleBuffer),
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        let timestamp = CACurrentMediaTime()
        guard timestamp - lastAnalysisTimestamp >= AppConstants.ImageProcessing.liveDetectionInterval else {
            return
        }
        lastAnalysisTimestamp = timestamp

        let document = documentScannerService.detectDocument(in: pixelBuffer)
        handleLiveDetectionResult(document)
    }
}

// MARK: - Preview

#Preview {
    ReceiptCameraView(
        onPhotoCaptured: { _ in },
        onCancel: {}
    )
}
