//
//  AuditFormView.swift
//  DoorAuditApp
//
//  View for auditing/reviewing a captured receipt
//  ENHANCED: Pre-fills OCR data, collapsible issue cards, sticky action bar
//  Designed for quick door audit workflow
//  Created: December 2025
//

import SwiftUI

struct AuditFormView: View {
    
    // MARK: - Properties
    
    let receipt: Receipt
    
    @Environment(\.dependencies) private var dependencies
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - State
    
    @State private var receiptImage: UIImage?
    @State private var isLoadingImage = true
    
    // Pre-filled from OCR
    @State private var register: String = ""
    @State private var ring: String = ""
    @State private var cashierNumber: String = ""
    @State private var totalAmount: String = ""
    
    // Audit form fields
    @State private var staffName: String = ""
    @State private var auditorName: String = ""
    @State private var notes: String = ""
    
    // Audit checks
    @State private var bobChecked = false
    @State private var threeTotalChecked = false
    @State private var prescanChecked = false
    @State private var prescanMatchChecked = false
    
    // Issues - Overcharge
    @State private var itemOvercharge: String = ""
    @State private var itemOverchargeName: String = ""
    @State private var itemOverchargeCost: String = ""
    
    // Issues - Undercharge
    @State private var itemUndercharge: String = ""
    @State private var itemUnderchargeName: String = ""
    @State private var itemUnderchargeCost: String = ""
    
    // Week
    @State private var week: String = ""
    
    // UI State
    @State private var isSaving = false
    @State private var showSaveSuccess = false
    @State private var saveError: Error?
    @State private var showImageFullscreen = false
    @State private var showAllItems = false
    @State private var showDetails = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 20) {
                    // Receipt Preview Card
                    receiptCard
                    
                    // Issues Section (Primary)
                    issuesSection
                    
                    // Quick Staff Selection
                    staffSection
                    
                    // Audit Checks
                    checksSection
                    
                    // Expandable Details
                    if showDetails {
                        detailsSection
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                    
                    // Toggle for details
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            showDetails.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text(showDetails ? "Hide Details" : "Show More Details")
                            Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.vertical, 8)
                    }
                    
                    // Bottom spacing for action bar
                    Spacer(minLength: 100)
                }
                .padding()
            }
            
            // Sticky Action Bar
            actionBar
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Quick Audit")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadReceiptImage()
            prefillFromReceipt()
            await loadExistingAudit()
        }
        .alert("Audit Saved", isPresented: $showSaveSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("The audit has been saved successfully.")
        }
        .alert("Save Error", isPresented: Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError?.localizedDescription ?? "Unknown error")
        }
        .fullScreenCover(isPresented: $showImageFullscreen) {
            FullscreenImageView(image: receiptImage, isPresented: $showImageFullscreen)
        }
        .sheet(isPresented: $showAllItems) {
            AllItemsSheet(items: receipt.lineItems)
        }
    }
    
    // MARK: - Receipt Card
    
    private var receiptCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                // Thumbnail - tap to view full
                Button {
                    showImageFullscreen = true
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        if isLoadingImage {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 80, height: 100)
                                .overlay(ProgressView())
                        } else if let image = receiptImage {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 100)
                                .cornerRadius(8)
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.gray.opacity(0.15))
                                .frame(width: 80, height: 100)
                                .overlay(
                                    Image(systemName: "doc.text")
                                        .font(.title2)
                                        .foregroundColor(.gray)
                                )
                        }
                        
                        // Magnifier icon
                        Image(systemName: "magnifyingglass.circle.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                            .offset(x: 4, y: 4)
                    }
                }
                .buttonStyle(.plain)
                
                // Receipt Info
                VStack(alignment: .leading, spacing: 8) {
                    // Transaction ID
                    HStack(spacing: 4) {
                        if let reg = receipt.registerNumber {
                            Label("Reg \(reg)", systemImage: "printer")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let trans = receipt.transactionNumber {
                            Text("•")
                                .foregroundColor(.secondary)
                            Text("#\(trans)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Total
                    if let total = receipt.totalAmount {
                        Text(String(format: "$%.2f", total))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }
                    
                    // Item Count with validation
                    HStack(spacing: 6) {
                        let count = receipt.lineItems.count
                        let expected = receipt.expectedItemCount ?? 0
                        let isMatch = expected == 0 || count == expected
                        
                        Button {
                            showAllItems = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: isMatch ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                    .foregroundColor(isMatch ? .green : .orange)
                                    .font(.caption)
                                
                                Text("\(count) items")
                                    .font(.subheadline)
                                    .foregroundColor(.primary)
                                
                                if expected > 0 && !isMatch {
                                    Text("(expected \(expected))")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                }
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Time
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                        Text(receipt.displayTime)
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(16)
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 5, y: 2)
    }
    
    // MARK: - Issues Section
    
    private var issuesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Issues Found")
                .font(.headline)
                .padding(.horizontal, 4)
            
            // Overcharge Card
            IssueInputCard(
                title: "Overcharge",
                subtitle: "Item charged but not in basket",
                iconName: "arrow.up.circle.fill",
                iconColor: CostcoTheme.Colors.secondary,
                itemNumber: $itemOvercharge,
                itemName: $itemOverchargeName,
                itemCost: $itemOverchargeCost,
                lineItems: receipt.lineItems
            )
            
            // Undercharge Card
            IssueInputCard(
                title: "Undercharge",
                subtitle: "Item in basket but not charged",
                iconName: "arrow.down.circle.fill",
                iconColor: .orange,
                itemNumber: $itemUndercharge,
                itemName: $itemUnderchargeName,
                itemCost: $itemUnderchargeCost,
                lineItems: receipt.lineItems
            )
        }
    }
    
    // MARK: - Staff Section
    
    private var staffSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Staff")
                .font(.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 12) {
                // Security
                HStack {
                    Text("Security")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Picker("Security", selection: $staffName) {
                        Text("Select...").tag("")
                        ForEach(StaffConfiguration.securityNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Supervisor
                HStack {
                    Text("Supervisor")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Picker("Supervisor", selection: $auditorName) {
                        Text("Select...").tag("")
                        ForEach(StaffConfiguration.supervisorNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Week
                HStack {
                    Text("Week")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .leading)
                    
                    Picker("Week", selection: $week) {
                        ForEach(StaffConfiguration.weekOptions, id: \.self) { w in
                            Text(w).tag(w)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Checks Section
    
    private var checksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Audit Checks")
                .font(.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 0) {
                AuditCheckRow(title: "B.O.B", isChecked: $bobChecked)
                Divider().padding(.leading, 16)
                AuditCheckRow(title: "3/ TOTAL", isChecked: $threeTotalChecked)
                Divider().padding(.leading, 16)
                AuditCheckRow(title: "PRESCAN", isChecked: $prescanChecked)
                Divider().padding(.leading, 16)
                AuditCheckRow(title: "PRESCAN # = BASKET #", isChecked: $prescanMatchChecked)
            }
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Details Section
    
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Receipt Details")
                .font(.headline)
                .padding(.horizontal, 4)
            
            VStack(spacing: 8) {
                DetailRow(label: "Date", value: receipt.displayDate)
                DetailRow(label: "Register", value: receipt.registerNumber ?? "-")
                DetailRow(label: "Transaction", value: receipt.transactionNumber ?? "-")
                DetailRow(label: "Cashier #", value: receipt.cashierNumber ?? "-")
                DetailRow(label: "Member ID", value: receipt.memberID ?? "-")
                if let barcode = receipt.barcodeValue {
                    DetailRow(label: "Barcode", value: barcode)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
    
    // MARK: - Action Bar
    
    private var actionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                // Complete button
                Button {
                    Task { await saveAudit() }
                } label: {
                    HStack {
                        if isSaving {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(isSaving ? "Saving..." : "Complete Audit")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(staffName.isEmpty ? Color.gray : CostcoTheme.Colors.success)
                    .cornerRadius(12)
                }
                .disabled(isSaving || staffName.isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
    
    // MARK: - Methods
    
    private func prefillFromReceipt() {
        register = receipt.registerNumber ?? ""
        ring = receipt.transactionNumber ?? ""
        cashierNumber = receipt.cashierNumber ?? ""
        
        if let total = receipt.totalAmount {
            totalAmount = String(format: "%.2f", total)
        }
        
        week = StaffConfiguration.currentWeek
    }
    
    private func loadReceiptImage() async {
        guard let imageID = receipt.imageID else {
            await MainActor.run { isLoadingImage = false }
            return
        }
        
        do {
            if let image = try await dependencies.imageRepository.fetchImage(id: imageID) {
                await MainActor.run {
                    self.receiptImage = image
                    self.isLoadingImage = false
                }
            } else {
                await MainActor.run { isLoadingImage = false }
            }
        } catch {
            Logger.shared.error("Failed to load receipt image", error: error)
            await MainActor.run { isLoadingImage = false }
        }
    }
    
    private func loadExistingAudit() async {
        if let existingAudit = try? await dependencies.auditRepository.fetchAudit(for: receipt.id) {
            await MainActor.run {
                staffName = existingAudit.staffName
                auditorName = existingAudit.auditorName ?? ""
                notes = existingAudit.notes ?? ""
                
                // Parse checks and issues from notes
                parseAuditData(from: existingAudit)
            }
        }
    }
    
    private func parseAuditData(from audit: AuditData) {
        if let notes = audit.notes {
            let components = notes.components(separatedBy: "|")
            for component in components {
                let trimmed = component.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("BOB:") { bobChecked = trimmed.contains("Y") }
                else if trimmed.hasPrefix("3/TOTAL:") { threeTotalChecked = trimmed.contains("Y") }
                else if trimmed.hasPrefix("PRESCAN:") && !trimmed.contains("MATCH") { prescanChecked = trimmed.contains("Y") }
                else if trimmed.hasPrefix("PRESCAN MATCH:") { prescanMatchChecked = trimmed.contains("Y") }
                else if trimmed.hasPrefix("Week:") {
                    week = String(trimmed.dropFirst("Week:".count)).trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Parse issues
        if let issue1 = audit.issue1 {
            if issue1.contains("OVERCHARGE") {
                parseIssue(issue1, itemNumber: &itemOvercharge, itemName: &itemOverchargeName, itemCost: &itemOverchargeCost)
            } else if issue1.contains("UNDERCHARGE") {
                parseIssue(issue1, itemNumber: &itemUndercharge, itemName: &itemUnderchargeName, itemCost: &itemUnderchargeCost)
            }
        }
        
        if let issue2 = audit.issue2 {
            if issue2.contains("UNDERCHARGE") {
                parseIssue(issue2, itemNumber: &itemUndercharge, itemName: &itemUnderchargeName, itemCost: &itemUnderchargeCost)
            } else if issue2.contains("OVERCHARGE") {
                parseIssue(issue2, itemNumber: &itemOvercharge, itemName: &itemOverchargeName, itemCost: &itemOverchargeCost)
            }
        }
    }
    
    private func parseIssue(_ issue: String, itemNumber: inout String, itemName: inout String, itemCost: inout String) {
        if let hashIndex = issue.firstIndex(of: "#") {
            let afterHash = String(issue[issue.index(after: hashIndex)...])
            let parts = afterHash.components(separatedBy: " - ")
            if parts.count >= 1 { itemNumber = parts[0].trimmingCharacters(in: .whitespaces) }
            if parts.count >= 2 { itemName = parts[1].trimmingCharacters(in: .whitespaces) }
            if parts.count >= 3 { itemCost = parts[2].replacingOccurrences(of: "$", with: "").trimmingCharacters(in: .whitespaces) }
        }
    }
    
    private func buildNotesWithData() -> String {
        var parts: [String] = []
        
        parts.append("BOB: \(bobChecked ? "Y" : "N")")
        parts.append("3/TOTAL: \(threeTotalChecked ? "Y" : "N")")
        parts.append("PRESCAN: \(prescanChecked ? "Y" : "N")")
        parts.append("PRESCAN MATCH: \(prescanMatchChecked ? "Y" : "N")")
        parts.append("Week: \(week)")
        
        if !notes.isEmpty {
            parts.append("Notes: \(notes)")
        }
        
        return parts.joined(separator: " | ")
    }
    
    private func buildIssueString(type: String, number: String, name: String, cost: String) -> String? {
        // Trim whitespace and check if actually has content
        let trimmedNumber = number.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCost = cost.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Only create issue if we have at least an item number
        guard !trimmedNumber.isEmpty else { return nil }
        
        var issue = "\(type): #\(trimmedNumber)"
        if !trimmedName.isEmpty { issue += " - \(trimmedName)" }
        if !trimmedCost.isEmpty { issue += " - $\(trimmedCost)" }
        return issue
    }
    
    @MainActor
    private func saveAudit() async {
        guard !staffName.isEmpty else {
            saveError = AuditFormError.missingStaff
            return
        }
        
        isSaving = true
        
        do {
            let notesWithData = buildNotesWithData()
            
            // Debug log the issue values before building
            Logger.shared.debug("📝 itemOvercharge: '\(itemOvercharge)' (length: \(itemOvercharge.count))")
            Logger.shared.debug("📝 itemUndercharge: '\(itemUndercharge)' (length: \(itemUndercharge.count))")
            
            let overchargeIssue = buildIssueString(type: "OVERCHARGE", number: itemOvercharge, name: itemOverchargeName, cost: itemOverchargeCost)
            let underchargeIssue = buildIssueString(type: "UNDERCHARGE", number: itemUndercharge, name: itemUnderchargeName, cost: itemUnderchargeCost)
            
            Logger.shared.debug("📝 overchargeIssue: \(overchargeIssue ?? "nil")")
            Logger.shared.debug("📝 underchargeIssue: \(underchargeIssue ?? "nil")")
            
            let audit = AuditData(
                receiptID: receipt.id,
                staffName: staffName,
                auditorName: auditorName.isEmpty ? nil : auditorName,
                itemCount: receipt.lineItems.count,
                notes: notesWithData,
                issue1: overchargeIssue,
                issue2: underchargeIssue,
                issue3: nil
            )
            
            try await dependencies.saveAuditUseCase.execute(audit: audit)
            
            isSaving = false
            showSaveSuccess = true
            
        } catch {
            Logger.shared.error("Failed to save audit", error: error)
            isSaving = false
            saveError = error
        }
    }
}

// MARK: - Supporting Views

struct IssueInputCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let iconColor: Color
    @Binding var itemNumber: String
    @Binding var itemName: String
    @Binding var itemCost: String
    let lineItems: [LineItem]
    
    @State private var isExpanded = false
    @State private var showItemPicker = false
    @State private var searchText = ""
    
    private var hasValue: Bool {
        !itemNumber.isEmpty
    }
    
    private var filteredItems: [LineItem] {
        if searchText.isEmpty {
            return lineItems
        }
        let query = searchText.lowercased()
        return lineItems.filter { item in
            item.description.lowercased().contains(query) ||
            (item.itemNumber.map { String($0) }?.contains(query) ?? false)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header - always visible
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(hasValue ? iconColor : .gray)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(hasValue ? iconColor : .primary)
                        
                        if hasValue {
                            Text("#\(itemNumber) - \(itemName.isEmpty ? "Unknown" : itemName)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            .buttonStyle(.plain)
            
            // Expanded content
            if isExpanded {
                Divider()
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    // Quick Select from Receipt Items
                    if !lineItems.isEmpty {
                        Button {
                            showItemPicker = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "list.bullet.rectangle.portrait")
                                    .font(.subheadline)
                                Text("Select from Receipt Items")
                                    .font(.subheadline)
                                Spacer()
                                Text("\(lineItems.count) items")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .foregroundColor(iconColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(iconColor.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    // Manual Entry Section
                    VStack(spacing: 8) {
                        HStack {
                            Text("Or enter manually:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        
                        // Item Number
                        HStack {
                            Text("Item #")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            TextField("Enter item number", text: $itemNumber)
                                .keyboardType(.numberPad)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Item Name
                        HStack {
                            Text("Name")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            TextField("Item name", text: $itemName)
                                .textFieldStyle(.roundedBorder)
                        }
                        
                        // Cost
                        HStack {
                            Text("Cost")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .frame(width: 60, alignment: .leading)
                            
                            HStack {
                                Text("$")
                                    .foregroundColor(.secondary)
                                TextField("0.00", text: $itemCost)
                                    .keyboardType(.decimalPad)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                    }
                    
                    // Clear button
                    if hasValue {
                        Button {
                            itemNumber = ""
                            itemName = ""
                            itemCost = ""
                        } label: {
                            HStack {
                                Image(systemName: "xmark.circle.fill")
                                Text("Clear")
                            }
                            .font(.subheadline)
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showItemPicker) {
            ItemPickerSheet(
                lineItems: lineItems,
                iconColor: iconColor,
                onSelect: { item in
                    selectItem(item)
                    showItemPicker = false
                },
                onCancel: {
                    showItemPicker = false
                }
            )
        }
    }
    
    private func selectItem(_ item: LineItem) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let num = item.itemNumber {
                itemNumber = String(num)
            }
            itemName = item.description
            if let price = item.price ?? item.total {
                itemCost = String(format: "%.2f", price)
            }
        }
    }
}

// MARK: - Item Picker Sheet

struct ItemPickerSheet: View {
    let lineItems: [LineItem]
    let iconColor: Color
    let onSelect: (LineItem) -> Void
    let onCancel: () -> Void
    
    @State private var searchText = ""
    
    private var filteredItems: [LineItem] {
        if searchText.isEmpty {
            return lineItems
        }
        let query = searchText.lowercased()
        return lineItems.filter { item in
            item.description.lowercased().contains(query) ||
            (item.itemNumber.map { String($0) }?.contains(query) ?? false)
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search items...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Items list
                if filteredItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("No items found")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        if !searchText.isEmpty {
                            Text("Try a different search term")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(filteredItems) { item in
                            ItemPickerRow(item: item, iconColor: iconColor)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    onSelect(item)
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Select Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        onCancel()
                    }
                }
            }
        }
    }
}

struct ItemPickerRow: View {
    let item: LineItem
    let iconColor: Color
    
    var body: some View {
        HStack(spacing: 12) {
            // Item number badge
            if let itemNum = item.itemNumber {
                Text("#\(itemNum)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundColor(iconColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(6)
            } else {
                Text("N/A")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.systemGray5))
                    .cornerRadius(6)
            }
            
            // Item details
            VStack(alignment: .leading, spacing: 2) {
                Text(item.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if let qty = item.quantity, qty > 1 {
                    Text("Qty: \(qty)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Price
            if let price = item.price ?? item.total {
                Text(String(format: "$%.2f", price))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            }
            
            // Selection indicator
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 8)
    }
}

struct AuditCheckRow: View {
    let title: String
    @Binding var isChecked: Bool
    
    var body: some View {
        Button {
            isChecked.toggle()
        } label: {
            HStack {
                Text(title)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Image(systemName: isChecked ? "checkmark.square.fill" : "square")
                    .font(.title2)
                    .foregroundColor(isChecked ? CostcoTheme.Colors.success : .gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
        }
    }
}

struct FullscreenImageView: View {
    let image: UIImage?
    @Binding var isPresented: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .gesture(
                            MagnificationGesture()
                                .onChanged { value in scale = lastScale * value }
                                .onEnded { _ in lastScale = scale }
                        )
                        .onTapGesture(count: 2) {
                            withAnimation {
                                if scale > 1.0 { scale = 1.0; lastScale = 1.0 }
                                else { scale = 2.0; lastScale = 2.0 }
                            }
                        }
                }
            }
            .navigationTitle("Receipt Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.black.opacity(0.8), for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Text("\(Int(scale * 100))%")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isPresented = false }
                        .foregroundColor(.white)
                }
            }
        }
    }
}

struct AllItemsSheet: View {
    let items: [LineItem]
    @Environment(\.dismiss) private var dismiss
    
    private var totalCost: Double {
        items.reduce(0) { $0 + ($1.total ?? $1.price ?? 0) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.description)
                                    .font(.subheadline)
                                
                                if let qty = item.quantity, qty > 1 {
                                    Text("Qty: \(qty)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            Spacer()
                            
                            if let price = item.price {
                                Text(String(format: "$%.2f", price))
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } header: {
                    Text("\(items.count) Items")
                } footer: {
                    if totalCost > 0 {
                        HStack {
                            Spacer()
                            Text("Total: \(String(format: "$%.2f", totalCost))")
                                .font(.headline)
                        }
                    }
                }
            }
            .navigationTitle("Line Items")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Errors

enum AuditFormError: LocalizedError {
    case missingStaff
    case saveFailed
    
    var errorDescription: String? {
        switch self {
        case .missingStaff: return "Please select a security staff member"
        case .saveFailed: return "Failed to save audit"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        AuditFormView(receipt: Receipt.sample)
            .environment(\.dependencies, DependencyContainer.shared)
    }
}
