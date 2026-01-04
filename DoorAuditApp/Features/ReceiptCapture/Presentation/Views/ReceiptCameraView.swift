//
//  ReceiptCameraView.swift
//  DoorAuditApp
//
//  ENHANCED: Real-time receipt detection with Vision framework
//  Shows green outline when receipt is detected
//  Auto-crops to receipt bounds on capture
//  Integrated with Clean Architecture use cases
//
//  Created: December 2025
//

import SwiftUI
import AVFoundation
import Vision

// MARK: - Constants

private enum CameraConstants {
    static let sessionQueueLabel = "camera.session.queue"
    static let detectionQueueLabel = "receipt.detection.queue"
    static let flashFeedbackOpacity: Double = 0.3
    static let flashFeedbackDuration: TimeInterval = 0.1
    static let detectionInterval: TimeInterval = 0.1 // 10 FPS for detection
    static let noDetectionThreshold = 5  // Frames before hiding rectangle
    static let stabilizationThreshold: CGFloat = 0.02  // Movement threshold for smoothing
}

// MARK: - Detected Rectangle

struct DetectedRectangle: Equatable {
    let topLeft: CGPoint
    let topRight: CGPoint
    let bottomLeft: CGPoint
    let bottomRight: CGPoint
    let boundingBox: CGRect
    let confidence: Float
    
    /// Convert Vision coordinates to view coordinates
    func toViewCoordinates(in size: CGSize) -> DetectedRectangle {
        // Vision uses bottom-left origin, SwiftUI uses top-left
        DetectedRectangle(
            topLeft: CGPoint(x: topLeft.x * size.width, y: (1 - topLeft.y) * size.height),
            topRight: CGPoint(x: topRight.x * size.width, y: (1 - topRight.y) * size.height),
            bottomLeft: CGPoint(x: bottomLeft.x * size.width, y: (1 - bottomLeft.y) * size.height),
            bottomRight: CGPoint(x: bottomRight.x * size.width, y: (1 - bottomRight.y) * size.height),
            boundingBox: CGRect(
                x: boundingBox.minX * size.width,
                y: (1 - boundingBox.maxY) * size.height,
                width: boundingBox.width * size.width,
                height: boundingBox.height * size.height
            ),
            confidence: confidence
        )
    }
}

// MARK: - Receipt Camera View

struct ReceiptCameraView: View {
    let onPhotoCaptured: (UIImage) -> Void
    let onCancel: () -> Void
    
    @StateObject private var cameraManager = CameraManager()
    @State private var showingPermissionAlert = false
    @State private var hasDeliveredImage = false
    
    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
            
            // Receipt detection overlay
            GeometryReader { geometry in
                ZStack {
                    // Detected rectangle overlay
                    if let rect = cameraManager.detectedRectangle {
                        let viewRect = rect.toViewCoordinates(in: geometry.size)
                        
                        // Draw the detected rectangle
                        Path { path in
                            path.move(to: viewRect.topLeft)
                            path.addLine(to: viewRect.topRight)
                            path.addLine(to: viewRect.bottomRight)
                            path.addLine(to: viewRect.bottomLeft)
                            path.closeSubpath()
                        }
                        .stroke(Color.green, lineWidth: 3)
                        
                        // Corner indicators - fixed to use index as id
                        ForEach(Array(zip([0, 1, 2, 3], [viewRect.topLeft, viewRect.topRight, viewRect.bottomLeft, viewRect.bottomRight])), id: \.0) { _, corner in
                            Circle()
                                .fill(Color.green)
                                .frame(width: 12, height: 12)
                                .position(corner)
                        }
                    } else {
                        // Static guide when no receipt detected
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.5), lineWidth: 2)
                            .frame(width: geometry.size.width * 0.85, height: geometry.size.height * 0.7)
                    }
                }
            }
            
            // Overlay UI
            VStack {
                // Top bar
                topBar
                
                Spacer()
                
                // Detection status
                detectionStatus
                
                Spacer()
                
                // Bottom controls
                bottomControls
            }
            
            // Flash feedback
            if cameraManager.isCapturing {
                Color.white
                    .ignoresSafeArea()
                    .opacity(CameraConstants.flashFeedbackOpacity)
                    .animation(.easeOut(duration: CameraConstants.flashFeedbackDuration), value: cameraManager.isCapturing)
            }
        }
        .onAppear {
            checkPermissionsAndStart()
        }
        .onDisappear {
            cameraManager.stop()
        }
        .alert("Camera Permission Required", isPresented: $showingPermissionAlert) {
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {
                onCancel()
            }
        } message: {
            Text("Please enable camera access in Settings to scan receipts.")
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
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
            
            // Flash toggle
            Button {
                cameraManager.toggleFlash()
            } label: {
                Image(systemName: flashIconName)
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
        }
        .padding()
    }
    
    private var flashIconName: String {
        switch cameraManager.flashMode {
        case .auto: return "bolt.badge.automatic"
        case .on: return "bolt.fill"
        case .off: return "bolt.slash"
        @unknown default: return "bolt.badge.automatic"
        }
    }
    
    // MARK: - Detection Status
    
    private var detectionStatus: some View {
        HStack(spacing: 8) {
            Image(systemName: cameraManager.detectedRectangle != nil ? "checkmark.circle.fill" : "viewfinder")
                .foregroundColor(cameraManager.detectedRectangle != nil ? .green : .white)
            
            Text(cameraManager.detectedRectangle != nil ? "Receipt Detected" : "Position Receipt in Frame")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.black.opacity(0.6))
        .cornerRadius(20)
    }
    
    // MARK: - Bottom Controls
    
    private var bottomControls: some View {
        HStack {
            // Library picker
            Button {
                // Fallback to photo library
                onCancel()
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(Color.black.opacity(0.5))
                    .clipShape(Circle())
            }
            
            Spacer()
            
            // Capture button
            Button {
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 70, height: 70)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .frame(width: 80, height: 80)
                    
                    if cameraManager.isCapturing {
                        ProgressView()
                            .tint(.gray)
                    }
                }
            }
            .disabled(cameraManager.isCapturing)
            
            Spacer()
            
            // Placeholder for symmetry
            Color.clear
                .frame(width: 50, height: 50)
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 30)
    }
    
    // MARK: - Methods
    
    private func checkPermissionsAndStart() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            cameraManager.configure()
            cameraManager.start()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        cameraManager.configure()
                        cameraManager.start()
                    } else {
                        showingPermissionAlert = true
                    }
                }
            }
            
        case .denied, .restricted:
            showingPermissionAlert = true
            
        @unknown default:
            showingPermissionAlert = true
        }
    }
    
    private func capturePhoto() {
        guard !hasDeliveredImage else {
            Logger.shared.warning("Already delivered image, ignoring capture")
            return
        }
        
        cameraManager.capturePhoto { image in
            guard let image = image, !hasDeliveredImage else { return }
            
            hasDeliveredImage = true
            
            DispatchQueue.main.async {
                onPhotoCaptured(image)
            }
        }
    }
}

// MARK: - Camera Manager

final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published State
    
    @Published var detectedRectangle: DetectedRectangle?
    @Published var isCapturing = false
    @Published var flashMode: AVCaptureDevice.FlashMode = .auto
    
    // MARK: - Session
    
    let session = AVCaptureSession()
    private let photoOutput = AVCapturePhotoOutput()
    private let videoOutput = AVCaptureVideoDataOutput()
    
    // MARK: - Queues
    
    private let sessionQueue = DispatchQueue(label: CameraConstants.sessionQueueLabel)
    private let detectionQueue = DispatchQueue(label: CameraConstants.detectionQueueLabel)
    
    // MARK: - Detection
    
    private var lastDetectionTime = Date.distantPast
    private let detectionInterval: TimeInterval = CameraConstants.detectionInterval
    
    // MARK: - Stabilization Properties
    
    private var consecutiveNoDetectionFrames = 0
    private var lastStableRectangle: DetectedRectangle?
    
    private lazy var rectangleRequest: VNDetectRectanglesRequest = {
        let request = VNDetectRectanglesRequest { [weak self] request, error in
            self?.handleRectangleDetection(request: request, error: error)
        }
        // Updated settings for better receipt detection
        request.minimumAspectRatio = 0.2
        request.maximumAspectRatio = 1.0  // Allow square-ish receipts too
        request.minimumSize = 0.1         // Allow smaller receipts
        request.minimumConfidence = 0.5   // Slightly more permissive
        request.maximumObservations = 1
        request.quadratureTolerance = 15  // Allow slightly skewed rectangles (degrees)
        return request
    }()
    
    // MARK: - Capture
    
    private var currentPhotoCaptureDelegate: PhotoCaptureDelegate?
    
    // MARK: - Configuration
    
    func configure() {
        sessionQueue.async { [weak self] in
            self?.configureSession()
        }
    }
    
    private func configureSession() {
        session.beginConfiguration()
        session.sessionPreset = .photo
        
        // Add camera input
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input) else {
            Logger.shared.error("Failed to configure camera input")
            session.commitConfiguration()
            return
        }
        
        session.addInput(input)
        
        // Add photo output
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
            // Enable high resolution capture
            photoOutput.isHighResolutionCaptureEnabled = true
            photoOutput.maxPhotoQualityPrioritization = .quality
        }
        
        // Add video output for real-time detection
        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
            videoOutput.setSampleBufferDelegate(self, queue: detectionQueue)
            videoOutput.alwaysDiscardsLateVideoFrames = true
            
            if let connection = videoOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
            }
        }
        
        session.commitConfiguration()
        Logger.shared.info("Camera session configured")
    }
    
    func start() {
        sessionQueue.async { [weak self] in
            guard let self = self, !self.session.isRunning else { return }
            self.session.startRunning()
            Logger.shared.info("Camera session started")
        }
    }
    
    func stop() {
        sessionQueue.async { [weak self] in
            guard let self = self, self.session.isRunning else { return }
            self.session.stopRunning()
            Logger.shared.info("Camera session stopped")
        }
    }
    
    func toggleFlash() {
        switch flashMode {
        case .auto: flashMode = .on
        case .on: flashMode = .off
        case .off: flashMode = .auto
        @unknown default: flashMode = .auto
        }
    }
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        guard !isCapturing else {
            Logger.shared.warning("Already capturing, ignoring request")
            return
        }
        
        DispatchQueue.main.async {
            self.isCapturing = true
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let settings = AVCapturePhotoSettings()
            
            if self.photoOutput.supportedFlashModes.contains(self.flashMode) {
                settings.flashMode = self.flashMode
            }
            
            // Enable high resolution photo
            settings.isHighResolutionPhotoEnabled = true
            
            let delegate = PhotoCaptureDelegate(cameraManager: self, completion: completion)
            self.currentPhotoCaptureDelegate = delegate
            self.photoOutput.capturePhoto(with: settings, delegate: delegate)
        }
    }
    
    private func handleRectangleDetection(request: VNRequest, error: Error?) {
        if let error = error {
            Logger.shared.debug("Rectangle detection error: \(error.localizedDescription)")
            return
        }
        
        guard let observations = request.results as? [VNRectangleObservation],
              let observation = observations.first else {
            // Don't immediately hide - wait for consecutive missed frames
            consecutiveNoDetectionFrames += 1
            
            if consecutiveNoDetectionFrames >= CameraConstants.noDetectionThreshold {
                DispatchQueue.main.async {
                    self.detectedRectangle = nil
                    self.lastStableRectangle = nil
                }
            }
            return
        }
        
        // Reset counter when we detect something
        consecutiveNoDetectionFrames = 0
        
        let detected = DetectedRectangle(
            topLeft: observation.topLeft,
            topRight: observation.topRight,
            bottomLeft: observation.bottomLeft,
            bottomRight: observation.bottomRight,
            boundingBox: observation.boundingBox,
            confidence: observation.confidence
        )
        
        // Apply stabilization - only update if movement is significant
        if let last = lastStableRectangle,
           !isSignificantMovement(from: last, to: detected) {
            // Keep the last stable rectangle to reduce jitter
            return
        }
        
        lastStableRectangle = detected
        
        DispatchQueue.main.async {
            self.detectedRectangle = detected
        }
    }
    
    /// Check if the rectangle has moved significantly enough to warrant an update
    private func isSignificantMovement(from old: DetectedRectangle, to new: DetectedRectangle) -> Bool {
        let corners = [
            (old.topLeft, new.topLeft),
            (old.topRight, new.topRight),
            (old.bottomLeft, new.bottomLeft),
            (old.bottomRight, new.bottomRight)
        ]
        
        for (oldCorner, newCorner) in corners {
            let distance = hypot(oldCorner.x - newCorner.x, oldCorner.y - newCorner.y)
            if distance > CameraConstants.stabilizationThreshold {
                return true
            }
        }
        return false
    }
}

// MARK: - Video Frame Processing

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Throttle detection
        let now = Date()
        guard now.timeIntervalSince(lastDetectionTime) >= detectionInterval else { return }
        lastDetectionTime = now
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .right, options: [:])
        
        do {
            try handler.perform([rectangleRequest])
        } catch {
            // Silently ignore - detection is best-effort
        }
    }
}

// MARK: - Photo Capture Delegate

private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private weak var cameraManager: CameraManager?
    private let completion: (UIImage?) -> Void
    
    init(cameraManager: CameraManager, completion: @escaping (UIImage?) -> Void) {
        self.cameraManager = cameraManager
        self.completion = completion
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        defer {
            DispatchQueue.main.async {
                self.cameraManager?.isCapturing = false
            }
        }
        
        if let error = error {
            Logger.shared.error("Photo capture error: \(error.localizedDescription)")
            completion(nil)
            return
        }
        
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            Logger.shared.error("Could not create image from photo data")
            completion(nil)
            return
        }
        
        // Fix orientation
        let fixedImage = image.fixedOrientation()
        
        // Try to crop to detected receipt
        if let croppedImage = ReceiptCropper.cropToReceipt(fixedImage) {
            Logger.shared.success("Cropped to receipt bounds")
            completion(croppedImage)
        } else {
            Logger.shared.info("Using full image (no receipt detected)")
            completion(fixedImage)
        }
    }
}

// MARK: - Camera Preview View

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.session = session
        return view
    }
    
    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {}
}

final class CameraPreviewUIView: UIView {
    var session: AVCaptureSession? {
        didSet {
            guard let session = session else { return }
            previewLayer.session = session
        }
    }
    
    private var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
    
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayer()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayer()
    }
    
    private func setupLayer() {
        previewLayer.videoGravity = .resizeAspectFill
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        if let connection = previewLayer.connection {
            let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene
            let orientation = windowScene?.interfaceOrientation ?? .portrait
            
            let videoOrientation: AVCaptureVideoOrientation
            switch orientation {
            case .portrait: videoOrientation = .portrait
            case .portraitUpsideDown: videoOrientation = .portraitUpsideDown
            case .landscapeLeft: videoOrientation = .landscapeLeft
            case .landscapeRight: videoOrientation = .landscapeRight
            default: videoOrientation = .portrait
            }
            
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = videoOrientation
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ReceiptCameraView(
        onPhotoCaptured: { _ in },
        onCancel: { }
    )
}
