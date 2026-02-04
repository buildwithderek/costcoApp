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
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(
                onCapture: { image in
                    capturedImage = image
                    showReview = true
                }
            )
            
            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button {
                        onCancel()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text("Position receipt in frame")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(20)
                    
                    Spacer()
                    
                    // Placeholder for symmetry
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                }
                .padding()
                
                Spacer()
                
                // Guide frame
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.7), lineWidth: 2)
                    .frame(width: 280, height: 400)
                
                Spacer()
                
                // Capture hint
                Text("Tap anywhere to capture")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
        .sheet(isPresented: $showReview) {
            if let image = capturedImage {
                ReviewImageView(
                    image: image,
                    onAccept: {
                        showReview = false
                        onPhotoCaptured(image)
                    },
                    onRetake: {
                        showReview = false
                        capturedImage = nil
                    }
                )
            }
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> CameraViewController {
        let controller = CameraViewController()
        controller.onCapture = onCapture
        return controller
    }
    
    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

// MARK: - Camera View Controller

class CameraViewController: UIViewController {
    var onCapture: ((UIImage) -> Void)?
    
    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var photoOutput: AVCapturePhotoOutput?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        
        // Add tap gesture for capture
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        view.addGestureRecognizer(tap)
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
    
    @objc private func handleTap() {
        guard let photoOutput = photoOutput else { return }
        
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }
}

// MARK: - Photo Capture Delegate

extension CameraViewController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
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

// MARK: - Review Image View

struct ReviewImageView: View {
    let image: UIImage
    let onAccept: () -> Void
    let onRetake: () -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Image preview
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black)
                
                // Action buttons
                HStack(spacing: 20) {
                    Button {
                        onRetake()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Retake")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray)
                        .cornerRadius(12)
                    }
                    
                    Button {
                        onAccept()
                    } label: {
                        HStack {
                            Image(systemName: "checkmark")
                            Text("Use Photo")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(CostcoTheme.Colors.success)
                        .cornerRadius(12)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
            .navigationTitle("Review Photo")
            .navigationBarTitleDisplayMode(.inline)
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
