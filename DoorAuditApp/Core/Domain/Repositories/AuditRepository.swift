//
//  AuditRepository.swift
//  L1 Demo
//
//  Protocol for audit persistence
//  Created: December 2025
//

import Foundation

/// Protocol defining audit persistence operations
protocol AuditRepository {
    
    // MARK: - Create
    
    /// Save a new audit or update existing
    func save(_ audit: AuditData) async throws
    
    /// Save multiple audits
    func saveAll(_ audits: [AuditData]) async throws
    
    // MARK: - Read
    
    /// Fetch an audit by ID
    func fetch(id: UUID) async throws -> AuditData?
    
    /// Fetch audit for a specific receipt
    func fetchAudit(for receiptID: UUID) async throws -> AuditData?
    
    /// Fetch all audits
    func fetchAll() async throws -> [AuditData]
    
    /// Fetch audits for a specific date
    func fetchAudits(for date: Date) async throws -> [AuditData]
    
    /// Fetch audits within a date range
    func fetchAudits(from startDate: Date, to endDate: Date) async throws -> [AuditData]
    
    /// Fetch audits with issues
    func fetchAuditsWithIssues() async throws -> [AuditData]
    
    /// Fetch completed audits
    func fetchCompletedAudits() async throws -> [AuditData]
    
    /// Fetch pending audits
    func fetchPendingAudits() async throws -> [AuditData]
    
    // MARK: - Update
    
    /// Update an existing audit
    func update(_ audit: AuditData) async throws
    
    // MARK: - Delete
    
    /// Delete an audit by ID
    func delete(id: UUID) async throws
    
    /// Delete an audit
    func delete(_ audit: AuditData) async throws
    
    /// Delete audits for a specific receipt
    func deleteAudits(for receiptID: UUID) async throws
    
    /// Delete all audits
    func deleteAll() async throws
    
    // MARK: - Count
    
    /// Get total count of audits
    func count() async throws -> Int
    
    /// Get count of audits with issues
    func countWithIssues() async throws -> Int
    
    /// Get count of completed audits
    func countCompleted() async throws -> Int
}

// MARK: - Default Implementations

extension AuditRepository {
    /// Fetch today's audits
    func fetchTodaysAudits() async throws -> [AuditData] {
        try await fetchAudits(for: Date())
    }
    
    /// Check if audit exists for receipt
    func hasAudit(for receiptID: UUID) async throws -> Bool {
        try await fetchAudit(for: receiptID) != nil
    }
}
