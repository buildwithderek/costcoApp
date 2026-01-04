//
//  SwiftDataPersistence.swift
//  L1 Demo
//
//  Complete SwiftData persistence implementation
//  Includes: Entities, Mapper, and Repository implementations
//  Created: December 2025
//

import Foundation
import SwiftData
import UIKit

// MARK: - SwiftData Entities

/// SwiftData entity for Receipt
/// ONLY handles persistence - no business logic
@Model
final class ReceiptEntity {
    @Attribute(.unique) var id: UUID
    var timestamp: Date
    var barcodeValue: String?
    var storeName: String?
    var purchaseDate: Date?
    var totalAmount: Double?
    var rawText: String
    var imageID: UUID?
    var cashierNumber: String?
    var registerNumber: String?
    var transactionNumber: String?
    var memberID: String?
    var expectedItemCount: Int?
    var lineItemsData: Data? // JSON encoded [LineItem]
    
    init(
        id: UUID,
        timestamp: Date,
        barcodeValue: String?,
        storeName: String?,
        purchaseDate: Date?,
        totalAmount: Double?,
        rawText: String,
        imageID: UUID?,
        cashierNumber: String?,
        registerNumber: String?,
        transactionNumber: String?,
        memberID: String?,
        expectedItemCount: Int?,
        lineItemsData: Data?
    ) {
        self.id = id
        self.timestamp = timestamp
        self.barcodeValue = barcodeValue
        self.storeName = storeName
        self.purchaseDate = purchaseDate
        self.totalAmount = totalAmount
        self.rawText = rawText
        self.imageID = imageID
        self.cashierNumber = cashierNumber
        self.registerNumber = registerNumber
        self.transactionNumber = transactionNumber
        self.memberID = memberID
        self.expectedItemCount = expectedItemCount
        self.lineItemsData = lineItemsData
    }
}

/// SwiftData entity for Audit
@Model
final class AuditEntity {
    @Attribute(.unique) var id: UUID
    var receiptID: UUID
    var timestamp: Date
    var staffName: String
    var auditorName: String?
    var itemCount: Int?
    var notes: String?
    var issue1: String?
    var issue2: String?
    var issue3: String?
    
    init(
        id: UUID,
        receiptID: UUID,
        timestamp: Date,
        staffName: String,
        auditorName: String?,
        itemCount: Int?,
        notes: String?,
        issue1: String?,
        issue2: String?,
        issue3: String?
    ) {
        self.id = id
        self.receiptID = receiptID
        self.timestamp = timestamp
        self.staffName = staffName
        self.auditorName = auditorName
        self.itemCount = itemCount
        self.notes = notes
        self.issue1 = issue1
        self.issue2 = issue2
        self.issue3 = issue3
    }
}

/// SwiftData entity for Images
@Model
final class ImageEntity {
    @Attribute(.unique) var id: UUID
    var imageData: Data
    var timestamp: Date
    var fileSize: Int64
    
    init(id: UUID, imageData: Data, timestamp: Date, fileSize: Int64) {
        self.id = id
        self.imageData = imageData
        self.timestamp = timestamp
        self.fileSize = fileSize
    }
}

// MARK: - Entity Mapper

/// Maps between Domain models and SwiftData entities
enum EntityMapper {
    
    // MARK: - Receipt Mapping
    
    static func toEntity(_ receipt: Receipt) -> ReceiptEntity {
        let lineItemsData = try? JSONEncoder().encode(receipt.lineItems)
        
        return ReceiptEntity(
            id: receipt.id,
            timestamp: receipt.timestamp,
            barcodeValue: receipt.barcodeValue,
            storeName: receipt.storeName,
            purchaseDate: receipt.purchaseDate,
            totalAmount: receipt.totalAmount,
            rawText: receipt.rawText,
            imageID: receipt.imageID,
            cashierNumber: receipt.cashierNumber,
            registerNumber: receipt.registerNumber,
            transactionNumber: receipt.transactionNumber,
            memberID: receipt.memberID,
            expectedItemCount: receipt.expectedItemCount,
            lineItemsData: lineItemsData
        )
    }
    
    static func toDomain(_ entity: ReceiptEntity) -> Receipt {
        var lineItems: [LineItem] = []
        if let data = entity.lineItemsData {
            lineItems = (try? JSONDecoder().decode([LineItem].self, from: data)) ?? []
        }
        
        return Receipt(
            id: entity.id,
            timestamp: entity.timestamp,
            barcodeValue: entity.barcodeValue,
            storeName: entity.storeName,
            purchaseDate: entity.purchaseDate,
            totalAmount: entity.totalAmount,
            rawText: entity.rawText,
            imageID: entity.imageID,
            cashierNumber: entity.cashierNumber,
            registerNumber: entity.registerNumber,
            transactionNumber: entity.transactionNumber,
            memberID: entity.memberID,
            expectedItemCount: entity.expectedItemCount,
            lineItems: lineItems
        )
    }
    
    // MARK: - Audit Mapping
    
    static func toEntity(_ audit: AuditData) -> AuditEntity {
        AuditEntity(
            id: audit.id,
            receiptID: audit.receiptID,
            timestamp: audit.timestamp,
            staffName: audit.staffName,
            auditorName: audit.auditorName,
            itemCount: audit.itemCount,
            notes: audit.notes,
            issue1: audit.issue1,
            issue2: audit.issue2,
            issue3: audit.issue3
        )
    }
    
    static func toDomain(_ entity: AuditEntity) -> AuditData {
        AuditData(
            id: entity.id,
            receiptID: entity.receiptID,
            timestamp: entity.timestamp,
            staffName: entity.staffName,
            auditorName: entity.auditorName,
            itemCount: entity.itemCount,
            notes: entity.notes,
            issue1: entity.issue1,
            issue2: entity.issue2,
            issue3: entity.issue3
        )
    }
}

// MARK: - SwiftData Receipt Repository

@MainActor
final class SwiftDataReceiptRepository: ReceiptRepository {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func save(_ receipt: Receipt) async throws {
        let entity = EntityMapper.toEntity(receipt)
        modelContext.insert(entity)
        try modelContext.save()
        Logger.shared.info("Saved receipt: \(receipt.id)")
    }
    
    func saveAll(_ receipts: [Receipt]) async throws {
        for receipt in receipts {
            let entity = EntityMapper.toEntity(receipt)
            modelContext.insert(entity)
        }
        try modelContext.save()
        Logger.shared.info("Saved \(receipts.count) receipts")
    }
    
    func fetch(id: UUID) async throws -> Receipt? {
        let descriptor = FetchDescriptor<ReceiptEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.first.map { EntityMapper.toDomain($0) }
    }
    
    func fetchAll() async throws -> [Receipt] {
        let descriptor = FetchDescriptor<ReceiptEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { EntityMapper.toDomain($0) }
    }
    
    func fetchReceipts(for date: Date) async throws -> [Receipt] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        
        let descriptor = FetchDescriptor<ReceiptEntity>(
            predicate: #Predicate { entity in
                entity.timestamp >= startOfDay && entity.timestamp <= endOfDay
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { EntityMapper.toDomain($0) }
    }
    
    func fetchReceipts(from startDate: Date, to endDate: Date) async throws -> [Receipt] {
        let descriptor = FetchDescriptor<ReceiptEntity>(
            predicate: #Predicate { entity in
                entity.timestamp >= startDate && entity.timestamp <= endDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { EntityMapper.toDomain($0) }
    }
    
    func fetchReceipts(matching predicate: @escaping (Receipt) -> Bool) async throws -> [Receipt] {
        let allReceipts = try await fetchAll()
        return allReceipts.filter(predicate)
    }
    
    func searchReceipts(query: String) async throws -> [Receipt] {
        let lowercased = query.lowercased()
        
        let descriptor = FetchDescriptor<ReceiptEntity>(
            predicate: #Predicate { entity in
                (entity.barcodeValue?.localizedStandardContains(lowercased) ?? false) ||
                (entity.transactionNumber?.localizedStandardContains(lowercased) ?? false) ||
                (entity.registerNumber?.localizedStandardContains(lowercased) ?? false) ||
                entity.rawText.localizedStandardContains(lowercased)
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { EntityMapper.toDomain($0) }
    }
    
    func update(_ receipt: Receipt) async throws {
        let receiptID = receipt.id
        guard let entity = try modelContext.fetch(
            FetchDescriptor<ReceiptEntity>(predicate: #Predicate { $0.id == receiptID })
        ).first else {
            throw RepositoryError.notFound
        }
        
        // Update all fields
        entity.timestamp = receipt.timestamp
        entity.barcodeValue = receipt.barcodeValue
        entity.storeName = receipt.storeName
        entity.purchaseDate = receipt.purchaseDate
        entity.totalAmount = receipt.totalAmount
        entity.rawText = receipt.rawText
        entity.imageID = receipt.imageID
        entity.cashierNumber = receipt.cashierNumber
        entity.registerNumber = receipt.registerNumber
        entity.transactionNumber = receipt.transactionNumber
        entity.memberID = receipt.memberID
        entity.expectedItemCount = receipt.expectedItemCount
        entity.lineItemsData = try? JSONEncoder().encode(receipt.lineItems)
        
        try modelContext.save()
        Logger.shared.info("Updated receipt: \(receipt.id)")
    }
    
    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<ReceiptEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entities = try modelContext.fetch(descriptor)
        
        for entity in entities {
            modelContext.delete(entity)
        }
        
        try modelContext.save()
        Logger.shared.info("Deleted receipt: \(id)")
    }
    
    func delete(_ receipt: Receipt) async throws {
        try await delete(id: receipt.id)
    }
    
    func deleteAll(_ receipts: [Receipt]) async throws {
        for receipt in receipts {
            try await delete(id: receipt.id)
        }
    }
    
    func count() async throws -> Int {
        let descriptor = FetchDescriptor<ReceiptEntity>()
        return try modelContext.fetchCount(descriptor)
    }
    
    func count(for date: Date) async throws -> Int {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        
        let descriptor = FetchDescriptor<ReceiptEntity>(
            predicate: #Predicate { entity in
                entity.timestamp >= startOfDay && entity.timestamp <= endOfDay
            }
        )
        
        return try modelContext.fetchCount(descriptor)
    }
}

// MARK: - SwiftData Audit Repository

@MainActor
final class SwiftDataAuditRepository: AuditRepository {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func save(_ audit: AuditData) async throws {
        let entity = EntityMapper.toEntity(audit)
        modelContext.insert(entity)
        try modelContext.save()
        Logger.shared.info("Saved audit: \(audit.id)")
    }
    
    func saveAll(_ audits: [AuditData]) async throws {
        for audit in audits {
            let entity = EntityMapper.toEntity(audit)
            modelContext.insert(entity)
        }
        try modelContext.save()
        Logger.shared.info("Saved \(audits.count) audits")
    }
    
    func fetch(id: UUID) async throws -> AuditData? {
        let descriptor = FetchDescriptor<AuditEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.first.map { EntityMapper.toDomain($0) }
    }
    
    func fetchAudit(for receiptID: UUID) async throws -> AuditData? {
        let descriptor = FetchDescriptor<AuditEntity>(
            predicate: #Predicate { $0.receiptID == receiptID }
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.first.map { EntityMapper.toDomain($0) }
    }
    
    func fetchAll() async throws -> [AuditData] {
        let descriptor = FetchDescriptor<AuditEntity>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.map { EntityMapper.toDomain($0) }
    }
    
    func fetchAudits(for date: Date) async throws -> [AuditData] {
        let startOfDay = date.startOfDay
        let endOfDay = date.endOfDay
        
        let descriptor = FetchDescriptor<AuditEntity>(
            predicate: #Predicate { entity in
                entity.timestamp >= startOfDay && entity.timestamp <= endOfDay
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { EntityMapper.toDomain($0) }
    }
    
    func fetchAudits(from startDate: Date, to endDate: Date) async throws -> [AuditData] {
        let descriptor = FetchDescriptor<AuditEntity>(
            predicate: #Predicate { entity in
                entity.timestamp >= startDate && entity.timestamp <= endDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { EntityMapper.toDomain($0) }
    }
    
    func fetchAuditsWithIssues() async throws -> [AuditData] {
        let allAudits = try await fetchAll()
        return allAudits.filter { audit in
            audit.issue1 != nil || audit.issue2 != nil || audit.issue3 != nil
        }
    }
    
    func fetchCompletedAudits() async throws -> [AuditData] {
        let allAudits = try await fetchAll()
        return allAudits.filter { audit in
            !audit.staffName.isEmpty &&
            audit.issue1 == nil &&
            audit.issue2 == nil &&
            audit.issue3 == nil
        }
    }
    
    func fetchPendingAudits() async throws -> [AuditData] {
        let descriptor = FetchDescriptor<AuditEntity>(
            predicate: #Predicate { entity in
                entity.staffName.isEmpty
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let entities = try modelContext.fetch(descriptor)
        return entities.map { EntityMapper.toDomain($0) }
    }
    
    func update(_ audit: AuditData) async throws {
        let auditID = audit.id
        guard let entity = try modelContext.fetch(
            FetchDescriptor<AuditEntity>(predicate: #Predicate { $0.id == auditID })
        ).first else {
            throw RepositoryError.notFound
        }
        
        entity.receiptID = audit.receiptID
        entity.timestamp = audit.timestamp
        entity.staffName = audit.staffName
        entity.auditorName = audit.auditorName
        entity.itemCount = audit.itemCount
        entity.notes = audit.notes
        entity.issue1 = audit.issue1
        entity.issue2 = audit.issue2
        entity.issue3 = audit.issue3
        
        try modelContext.save()
        Logger.shared.info("Updated audit: \(audit.id)")
    }
    
    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<AuditEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entities = try modelContext.fetch(descriptor)
        
        for entity in entities {
            modelContext.delete(entity)
        }
        
        try modelContext.save()
        Logger.shared.info("Deleted audit: \(id)")
    }
    
    func delete(_ audit: AuditData) async throws {
        try await delete(id: audit.id)
    }
    
    func deleteAudits(for receiptID: UUID) async throws {
        let descriptor = FetchDescriptor<AuditEntity>(
            predicate: #Predicate { $0.receiptID == receiptID }
        )
        let entities = try modelContext.fetch(descriptor)
        
        for entity in entities {
            modelContext.delete(entity)
        }
        
        try modelContext.save()
        Logger.shared.info("Deleted audits for receipt: \(receiptID)")
    }
    
    func deleteAll() async throws {
        try modelContext.delete(model: AuditEntity.self)
        Logger.shared.info("Deleted all audits")
    }
    
    func count() async throws -> Int {
        try modelContext.fetchCount(FetchDescriptor<AuditEntity>())
    }
    
    func countWithIssues() async throws -> Int {
        let auditsWithIssues = try await fetchAuditsWithIssues()
        return auditsWithIssues.count
    }
    
    func countCompleted() async throws -> Int {
        let completedAudits = try await fetchCompletedAudits()
        return completedAudits.count
    }
}

// MARK: - SwiftData Image Repository

@MainActor
final class SwiftDataImageRepository: ImageRepository {
    
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func save(_ imageData: Data) async throws -> UUID {
        let id = UUID()
        let entity = ImageEntity(
            id: id,
            imageData: imageData,
            timestamp: Date(),
            fileSize: Int64(imageData.count)
        )
        
        modelContext.insert(entity)
        try modelContext.save()
        Logger.shared.info("Saved image: \(id), size: \(imageData.count) bytes")
        
        return id
    }
    
    func save(_ image: UIImage, quality: CGFloat) async throws -> UUID {
        guard let imageData = image.jpegData(compressionQuality: quality) else {
            throw ImageError.compressionFailed
        }
        return try await save(imageData)
    }
    
    func fetch(id: UUID) async throws -> Data? {
        let descriptor = FetchDescriptor<ImageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.first?.imageData
    }
    
    func fetchImage(id: UUID) async throws -> UIImage? {
        guard let data = try await fetch(id: id) else { return nil }
        return UIImage(data: data)
    }
    
    func fetchThumbnail(id: UUID, size: CGSize) async throws -> UIImage? {
        guard let image = try await fetchImage(id: id) else { return nil }
        return image.resized(to: size)
    }
    
    func delete(id: UUID) async throws {
        let descriptor = FetchDescriptor<ImageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entities = try modelContext.fetch(descriptor)
        
        for entity in entities {
            modelContext.delete(entity)
        }
        
        try modelContext.save()
        Logger.shared.info("Deleted image: \(id)")
    }
    
    func deleteAll(ids: [UUID]) async throws {
        for id in ids {
            try await delete(id: id)
        }
    }
    
    func exists(id: UUID) async throws -> Bool {
        let descriptor = FetchDescriptor<ImageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let count = try modelContext.fetchCount(descriptor)
        return count > 0
    }
    
    func size(id: UUID) async throws -> Int64? {
        let descriptor = FetchDescriptor<ImageEntity>(
            predicate: #Predicate { $0.id == id }
        )
        let entities = try modelContext.fetch(descriptor)
        return entities.first?.fileSize
    }
}
