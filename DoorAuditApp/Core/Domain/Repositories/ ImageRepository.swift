//
//  ImageRepository.swift
//  L1 Demo
//
//  Protocol for image storage
//  Created: December 2025
//

import Foundation
import UIKit

/// Protocol defining image storage operations
/// Can be implemented with file system, SwiftData, CloudKit, etc.
protocol ImageRepository {
    
    // MARK: - Save
    
    /// Save an image and return its unique ID
    func save(_ imageData: Data) async throws -> UUID
    
    /// Save a UIImage and return its unique ID
    func save(_ image: UIImage, quality: CGFloat) async throws -> UUID
    
    // MARK: - Fetch
    
    /// Fetch image data by ID
    func fetch(id: UUID) async throws -> Data?
    
    /// Fetch UIImage by ID
    func fetchImage(id: UUID) async throws -> UIImage?
    
    /// Fetch thumbnail (smaller version)
    func fetchThumbnail(id: UUID, size: CGSize) async throws -> UIImage?
    
    // MARK: - Delete
    
    /// Delete an image by ID
    func delete(id: UUID) async throws
    
    /// Delete multiple images
    func deleteAll(ids: [UUID]) async throws
    
    // MARK: - Info
    
    /// Check if image exists
    func exists(id: UUID) async throws -> Bool
    
    /// Get image file size in bytes
    func size(id: UUID) async throws -> Int64?
}

// MARK: - Default Implementations

extension ImageRepository {
    /// Save UIImage with default quality
    func save(_ image: UIImage) async throws -> UUID {
        try await save(image, quality: AppConstants.ImageProcessing.jpegQuality)
    }
    
    /// Fetch thumbnail with default size
    func fetchThumbnail(id: UUID) async throws -> UIImage? {
        try await fetchThumbnail(id: id, size: AppConstants.ImageProcessing.thumbnailSize)
    }
}

// MARK: - Image Errors

enum ImageError: LocalizedError {
    case invalidImageData
    case imageNotFound
    case saveFailed(Error)
    case loadFailed(Error)
    case compressionFailed
    
    var errorDescription: String? {
        switch self {
        case .invalidImageData:
            return "Invalid image data"
        case .imageNotFound:
            return "Image not found"
        case .saveFailed(let error):
            return "Failed to save image: \(error.localizedDescription)"
        case .loadFailed(let error):
            return "Failed to load image: \(error.localizedDescription)"
        case .compressionFailed:
            return "Failed to compress image"
        }
    }
}
