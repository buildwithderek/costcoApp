//
//  AuditFormViewModel.swift
//  DoorAuditApp
//
//  ViewModel for audit form - handles business logic and state
//  Created: December 2025
//

import Foundation
import SwiftUI

@Observable
final class AuditFormViewModel {
    
    // MARK: - Dependencies
    
    private let receipt: Receipt
    private let saveAudit: SaveAuditUseCase
    private let auditRepository: AuditRepository
    
    // MARK: - State
    
    var isProcessing = false
    var error: Error?
    var showingDetails = false
    var isCompleted = false
    
    // MARK: - Audit Fields (matching spreadsheet columns)
    
    // Issues
    var itemOvercharge: String = ""
    var itemOverchargeName: String = ""
    var itemOverchargeCost: String = ""
    var itemUndercharge: String = ""
    var itemUnderchargeName: String = ""
    var itemUnderchargeCost: String = ""
    
    // Staff
    var security: String = ""
    var cashier: String = ""
    var assistant: String = ""
    var supervisor: String = ""
    var week: String = ""
    
    // Audit Checks
    var bob: Bool = false
    var threeTotal: Bool = false
    var prescan: Bool = false
    var prescanMatchesBasket: Bool = false
    
    // Line Items
    var lineItems: [LineItem]
    
    // MARK: - Initialization
    
    init(
        receipt: Receipt,
        saveAudit: SaveAuditUseCase,
        auditRepository: AuditRepository
    ) {
        self.receipt = receipt
        self.saveAudit = saveAudit
        self.auditRepository = auditRepository
        
        // Pre-fill line items from receipt
        self.lineItems = receipt.lineItems
        
        // Set default week
        self.week = StaffConfiguration.currentWeek
    }
    
    // MARK: - Load Existing Audit
    
    func loadExistingAudit() async {
        do {
            if let existingAudit = try await auditRepository.fetchAudit(for: receipt.id) {
                await MainActor.run {
                    // Load existing audit data
                    loadFromAudit(existingAudit)
                }
            }
        } catch {
            Logger.shared.error("Failed to load existing audit", error: error)
        }
    }
    
    private func loadFromAudit(_ audit: AuditData) {
        // Parse staff name as security
        self.security = audit.staffName
        
        // Parse notes for other fields (if stored there)
        // For now, notes are just notes
        
        // Load issues from audit
        if let issue1 = audit.issue1, !issue1.isEmpty {
            // Try to parse issue format: "OVERCHARGE: #12345 - Item Name - $5.99"
            parseIssue(issue1, isOvercharge: true)
        }
        
        if let issue2 = audit.issue2, !issue2.isEmpty {
            parseIssue(issue2, isOvercharge: false)
        }
    }
    
    private func parseIssue(_ issue: String, isOvercharge: Bool) {
        // Simple parsing - improve as needed
        let parts = issue.split(separator: "-").map { $0.trimmingCharacters(in: .whitespaces) }
        
        if parts.count >= 3 {
            if isOvercharge {
                itemOvercharge = String(parts[0])
                itemOverchargeName = String(parts[1])
                itemOverchargeCost = String(parts[2]).replacingOccurrences(of: "$", with: "")
            } else {
                itemUndercharge = String(parts[0])
                itemUnderchargeName = String(parts[1])
                itemUnderchargeCost = String(parts[2]).replacingOccurrences(of: "$", with: "")
            }
        }
    }
    
    // MARK: - Lookup Items
    
    func lookupOverchargeItem() {
        guard !itemOvercharge.isEmpty else { return }
        
        // Try to find item in line items by number or name
        if let item = findItemByNumber(itemOvercharge) {
            itemOverchargeName = item.description
            if let price = item.price {
                itemOverchargeCost = String(format: "%.2f", price)
            }
        }
    }
    
    func lookupUnderchargeItem() {
        guard !itemUndercharge.isEmpty else { return }
        
        // Try to find item in line items by number or name
        if let item = findItemByNumber(itemUndercharge) {
            itemUnderchargeName = item.description
            if let price = item.price {
                itemUnderchargeCost = String(format: "%.2f", price)
            }
        }
    }
    
    private func findItemByNumber(_ number: String) -> LineItem? {
        // First try to match by item number
        if let itemNum = Int(number) {
            if let item = lineItems.first(where: { $0.itemNumber == itemNum }) {
                return item
            }
        }
        
        // Then try to match by name containing the number
        if let item = lineItems.first(where: { $0.description.contains(number) }) {
            return item
        }
        
        return nil
    }
    
    // MARK: - Save Operations
    
    func saveDraft() async {
        await save(completed: false)
    }
    
    func completeAudit() async {
        await save(completed: true)
    }
    
    private func save(completed: Bool) async {
        isProcessing = true
        isCompleted = completed
        
        do {
            // Create audit data
            let audit = createAuditData()
            
            // Save audit
            try await saveAudit.execute(audit: audit)
            
            Logger.shared.success("Audit \(completed ? "completed" : "saved as draft")")
            
            await MainActor.run {
                isProcessing = false
            }
            
        } catch {
            Logger.shared.error("Failed to save audit", error: error)
            
            await MainActor.run {
                self.error = error
                isProcessing = false
            }
        }
    }
    
    private func createAuditData() -> AuditData {
        // Build issues strings
        var issue1: String? = nil
        var issue2: String? = nil
        let issue3: String? = nil
        
        // Overcharge issue
        if !itemOvercharge.isEmpty {
            issue1 = buildIssueString(
                number: itemOvercharge,
                name: itemOverchargeName,
                cost: itemOverchargeCost,
                type: "OVERCHARGE"
            )
        }
        
        // Undercharge issue
        if !itemUndercharge.isEmpty {
            issue2 = buildIssueString(
                number: itemUndercharge,
                name: itemUnderchargeName,
                cost: itemUnderchargeCost,
                type: "UNDERCHARGE"
            )
        }
        
        // Build notes with audit checks
        var notes = [String]()
        if bob { notes.append("BOB: Y") }
        if threeTotal { notes.append("3/TOTAL: Y") }
        if prescan { notes.append("PRESCAN: Y") }
        if prescanMatchesBasket { notes.append("PRESCAN MATCH: Y") }
        
        // Add staff info to notes
        if !cashier.isEmpty { notes.append("Cashier: \(cashier)") }
        if !assistant.isEmpty { notes.append("Asst: \(assistant)") }
        if !supervisor.isEmpty { notes.append("Sup: \(supervisor)") }
        if !week.isEmpty { notes.append("Week: \(week)") }
        
        let notesString = notes.isEmpty ? nil : notes.joined(separator: " | ")
        
        return AuditData(
            receiptID: receipt.id,
            timestamp: Date(),
            staffName: security.isEmpty ? "N/A" : security,
            auditorName: supervisor,
            itemCount: lineItems.count,
            notes: notesString,
            issue1: issue1,
            issue2: issue2,
            issue3: issue3
        )
    }
    
    private func buildIssueString(number: String, name: String, cost: String, type: String) -> String {
        var parts = [type]
        
        if !number.isEmpty {
            parts.append("#\(number)")
        }
        
        if !name.isEmpty {
            parts.append(name)
        }
        
        if !cost.isEmpty {
            let formattedCost = cost.hasPrefix("$") ? cost : "$\(cost)"
            parts.append(formattedCost)
        }
        
        return parts.joined(separator: " - ")
    }
    
    // MARK: - Error Handling
    
    func clearError() {
        error = nil
    }
}
