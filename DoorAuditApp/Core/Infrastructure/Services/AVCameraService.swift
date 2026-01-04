//
//  AVCameraService.swift
//  L1 Demo
//
//  Camera service using AVFoundation
//  Provides camera functionality as a service
//  Created: December 2025
//

import UIKit
import AVFoundation

/// Camera service for capturing photos
/// Can be extended with camera preview, flash control, etc.
final class AVCameraService: CameraService {
    
    // MARK: - Properties
    
    private var captureDevice: AVCaptureDevice?
    private var captureSession: AVCaptureSession?
    
    // MARK: - Initialization
    
    init() {
        setupCamera()
    }
    
    // MARK: - Setup
    
    private func setupCamera() {
        // Setup camera session if needed
        // For now, we'll rely on UIImagePickerController in the view
        Logger.shared.debug("Camera service initialized")
    }
    
    // MARK: - Camera Service Methods
    
    /// Check if camera is available
    func isCameraAvailable() -> Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    /// Request camera permission
    func requestCameraPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                Logger.shared.info("Camera permission: \(granted ? "granted" : "denied")")
                continuation.resume(returning: granted)
            }
        }
    }
    
    /// Check camera permission status
    func checkCameraPermission() -> AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }
    
    /// Get camera configuration for image picker
    func getCameraConfiguration() -> CameraConfiguration {
        CameraConfiguration(
            sourceType: .camera,
            allowsEditing: false,
            cameraCaptureMode: .photo,
            cameraDevice: .rear
        )
    }
}

// MARK: - Camera Errors

enum CameraError: LocalizedError {
    case notAvailable
    case permissionDenied
    case captureFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "Camera is not available on this device"
        case .permissionDenied:
            return "Camera permission is required to scan receipts. Please enable camera access in Settings."
        case .captureFailed:
            return "Failed to capture image. Please try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Go to Settings > Door Audit App > Camera to enable access."
        default:
            return nil
        }
    }
}
