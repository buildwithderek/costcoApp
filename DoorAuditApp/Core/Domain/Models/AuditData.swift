//
//  AuditData.swift
//  L1 Demo
//
//  Domain model for Audit information
//  Separated from Receipt for Single Responsibility
//  Created: December 2025
//

import Foundation

/// Audit information for a receipt
/// Separated from Receipt to follow Single Responsibility Principle
struct AuditData: Identifiable, Hashable, Codable {
    
    // MARK: - Identity
    
    let id: UUID
    let receiptID: UUID
    let timestamp: Date
    
    // MARK: - Audit Information
    
    let staffName: String
    let auditorName: String?
    let itemCount: Int?
    let notes: String?
    
    // MARK: - Issues
    
    let issue1: String?
    let issue2: String?
    let issue3: String?
    
    // MARK: - Status
    
    var status: AuditStatus {
        // Simple: if staff name filled = completed, otherwise pending
        if isComplete {
            return .completed
        } else {
            return .pending
        }
    }
    
    // MARK: - Computed Properties
    
    var hasIssues: Bool {
        // Still track if there are issues (for export/reporting), but don't affect status
        let issues = [issue1, issue2, issue3]
        return issues.contains { issue in
            guard let issue = issue else { return false }
            return !issue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    var isComplete: Bool {
        staffName.isEmpty == false
    }
    
    var allIssues: [String] {
        [issue1, issue2, issue3]
            .compactMap { $0 }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
    
    var issueCount: Int {
        allIssues.count
    }
    
    var displayDate: String {
        timestamp.displayString
    }
    
    // MARK: - Initialization
    
    init(
        id: UUID = UUID(),
        receiptID: UUID,
        timestamp: Date = Date(),
        staffName: String,
        auditorName: String? = nil,
        itemCount: Int? = nil,
        notes: String? = nil,
        issue1: String? = nil,
        issue2: String? = nil,
        issue3: String? = nil
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
    
    // MARK: - Methods
    
    /// Create a copy with updated values
    func with(
        staffName: String? = nil,
        auditorName: String? = nil,
        itemCount: Int? = nil,
        notes: String? = nil,
        issue1: String? = nil,
        issue2: String? = nil,
        issue3: String? = nil
    ) -> AuditData {
        AuditData(
            id: self.id,
            receiptID: self.receiptID,
            timestamp: self.timestamp,
            staffName: staffName ?? self.staffName,
            auditorName: auditorName ?? self.auditorName,
            itemCount: itemCount ?? self.itemCount,
            notes: notes ?? self.notes,
            issue1: issue1 ?? self.issue1,
            issue2: issue2 ?? self.issue2,
            issue3: issue3 ?? self.issue3
        )
    }
}

// MARK: - Audit Status

extension AuditData {
    enum AuditStatus: String, Codable {
        case pending = "Pending"
        case completed = "Completed"
        
        var displayName: String { rawValue }
        
        var iconName: String {
            switch self {
            case .pending: return CostcoTheme.Icons.pending
            case .completed: return CostcoTheme.Icons.success
            }
        }
    }
}

// MARK: - Validation

extension AuditData {
    enum ValidationError: LocalizedError {
        case missingStaffName
        case invalidItemCount
        
        var errorDescription: String? {
            switch self {
            case .missingStaffName:
                return "Staff name is required"
            case .invalidItemCount:
                return "Item count must be greater than 0"
            }
        }
    }
    
    func validate() throws {
        guard !staffName.isEmpty else {
            throw ValidationError.missingStaffName
        }
        
        if let count = itemCount, count <= 0 {
            throw ValidationError.invalidItemCount
        }
    }
}

// MARK: - Sample Data

extension AuditData {
    static let sample = AuditData(
        receiptID: UUID(),
        staffName: "John Doe",
        auditorName: "Jane Smith",
        itemCount: 12,
        notes: "All items verified",
        issue1: nil,
        issue2: nil,
        issue3: nil
    )
    
    static let sampleWithIssues = AuditData(
        receiptID: UUID(),
        staffName: "John Doe",
        itemCount: 8,
        notes: "Multiple discrepancies found",
        issue1: "Missing item #123456",
        issue2: "Wrong quantity on bananas",
        issue3: "Price mismatch on milk"
    )
    
    static let samplePending = AuditData(
        receiptID: UUID(),
        staffName: "John Doe"
    )
}
