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

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(
                captureTrigger: captureTrigger,
                onCaptureStarted: {
                    isCapturing = true
                },
                onCapture: { image in
                    capturedImage = image
                    isCapturing = false
                    showReview = true
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
                Text("Hold steady for a clear scan.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.85))
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

            Text("Need a better shot? You can retake before saving.")
                .font(.footnote)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 24)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewControllerRepresentable {
    let captureTrigger: Int
    let onCaptureStarted: () -> Void
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        return controller
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {
        if context.coordinator.lastCaptureTrigger != captureTrigger {
            context.coordinator.lastCaptureTrigger = captureTrigger
            onCaptureStarted()
            uiViewController.capturePhoto()
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
    var onCapture: ((UIImage) -> Void)?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    private var isCaptureInProgress = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
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

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds
        view.layer.addSublayer(previewLayer)

        self.captureSession = session
        self.previewLayer = previewLayer
        self.photoOutput = output
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
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

    func capturePhoto() {
        guard !isCaptureInProgress, let photoOutput = photoOutput else { return }

        isCaptureInProgress = true
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
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
            self?.onCapture?(image)
        }
    }
}

// MARK: - Preview

#Preview {
    ReceiptCameraView(
        onPhotoCaptured: { _ in },
        onCancel: {}
    )
}
