//
//  DependencyContainer.swift
//  DoorAuditApp
//
//  Dependency Injection Container
//  Single source of truth for the entire app
//  Created: December 2025
//

import Foundation
import SwiftData

/// Central dependency injection container
/// Creates and manages all app dependencies
@MainActor
final class DependencyContainer {
    
    // MARK: - Singleton
    
    static let shared = DependencyContainer()
    
    // MARK: - SwiftData
    
    let modelContext: ModelContext
    let modelContainer: ModelContainer
    
    // MARK: - Repositories
    
    lazy var receiptRepository: ReceiptRepository = {
        SwiftDataReceiptRepository(modelContext: modelContext)
    }()
    
    lazy var auditRepository: AuditRepository = {
        SwiftDataAuditRepository(modelContext: modelContext)
    }()
    
    lazy var imageRepository: ImageRepository = {
        SwiftDataImageRepository(modelContext: modelContext)
    }()
    
    // MARK: - Services
    
    lazy var ocrService: OCRService = {
        VisionOCRService()
    }()
    
    lazy var barcodeService: BarcodeService = {
        VisionBarcodeService()
    }()
    
    lazy var cameraService: CameraService = {
        AVCameraService()
    }()
    
    lazy var exportService: ExportService = {
        CSVExportService()
    }()
    
    // MARK: - Use Cases
    
    lazy var processReceiptUseCase: ProcessReceiptUseCase = {
        DefaultProcessReceiptUseCase(
            ocrService: ocrService,
            barcodeService: barcodeService,
            receiptRepository: receiptRepository,
            imageRepository: imageRepository
        )
    }()
    
    lazy var fetchReceiptsUseCase: FetchReceiptsUseCase = {
        DefaultFetchReceiptsUseCase(
            receiptRepository: receiptRepository
        )
    }()
    
    lazy var saveAuditUseCase: SaveAuditUseCase = {
        DefaultSaveAuditUseCase(
            auditRepository: auditRepository
        )
    }()
    
    lazy var deleteReceiptUseCase: DeleteReceiptUseCase = {
        DefaultDeleteReceiptUseCase(
            receiptRepository: receiptRepository,
            auditRepository: auditRepository,
            imageRepository: imageRepository
        )
    }()
    
    lazy var exportAuditsUseCase: ExportAuditsUseCase = {
        DefaultExportAuditsUseCase(
            receiptRepository: receiptRepository,
            auditRepository: auditRepository,
            imageRepository: imageRepository
        )
    }()
    
    // MARK: - Initialization
    
    private init() {
        Logger.shared.info("Initializing DependencyContainer...")
        
        // Create SwiftData schema
        let schema = Schema([
            ReceiptEntity.self,
            AuditEntity.self,
            ImageEntity.self
        ])
        
        // Configure model container
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            modelContainer = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            modelContext = ModelContext(modelContainer)
            
            Logger.shared.success("SwiftData initialized successfully")
        } catch {
            Logger.shared.error("Failed to initialize SwiftData", error: error)
            fatalError("Could not initialize ModelContainer: \(error)")
        }
        
        Logger.shared.success("DependencyContainer initialized")
    }
    
    // MARK: - ViewModel Factories
    
    /// Create ReceiptCaptureViewModel
    func makeReceiptCaptureViewModel() -> ReceiptCaptureViewModel {
        ReceiptCaptureViewModel(
            processReceipt: processReceiptUseCase,
            fetchReceipts: fetchReceiptsUseCase,
            deleteReceipt: deleteReceiptUseCase,
            cameraService: cameraService
        )
    }
    
    /// Create AuditViewModel
    func makeAuditViewModel(receipt: Receipt) -> AuditViewModel {
        AuditViewModel(
            receipt: receipt,
            auditRepository: auditRepository,
            saveAudit: saveAuditUseCase
        )
    }
    
    /// Create ExportViewModel
    func makeExportViewModel() -> ExportViewModel {
        ExportViewModel(
            exportAudits: exportAuditsUseCase,
            fetchReceipts: fetchReceiptsUseCase
        )
    }
    
    /// Create ReceiptListViewModel
    func makeReceiptListViewModel() -> ReceiptListViewModel {
        ReceiptListViewModel(
            fetchReceipts: fetchReceiptsUseCase,
            deleteReceipt: deleteReceiptUseCase,
            exportService: exportService
        )
    }
}

// MARK: - Preview Container

#if DEBUG
extension DependencyContainer {
    /// Container with mock data for SwiftUI previews
    static var preview: DependencyContainer {
        let container = DependencyContainer.shared
        
        // Add sample data to context for previews
        Task {
            let receipt = Receipt.sample
            try? await container.receiptRepository.save(receipt)
            
            let audit = AuditData.sample
            try? await container.auditRepository.save(audit)
        }
        
        return container
    }
}
#endif
