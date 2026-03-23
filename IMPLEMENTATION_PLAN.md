# DoorAuditApp — Implementation Plan

**Goal:** Enable Costco warehouse staff to capture receipts (camera or library), parse them via OCR, record door audit metadata (staff name, issues, notes), and export audits to CSV for reporting.

**Architecture:** Clean Architecture with Domain (models, repositories, use cases), Infrastructure (SwiftData persistence, Vision OCR/barcode, Costco receipt parser), and Features (ReceiptCapture, Audit, Export) with SwiftUI presentation layer and dependency injection.

**Tech Stack:** Swift 5, SwiftUI, SwiftData, Vision framework, AVFoundation, UIKit (UIImagePicker, camera)

---

## Task 1: Project Scaffolding

**Files:** `DoorAuditApp.xcodeproj/project.pbxproj`, `DoorAuditApp/Info.plist`, `DoorAuditApp/DoorAuditApp.swift`, `DoorAuditApp/Assets.xcassets/`

**Steps:**
1. Create Xcode project targeting iOS 17+
2. Add Info.plist keys: `NSCameraUsageDescription`, `NSPhotoLibraryUsageDescription`
3. Configure SwiftData and Vision/AVFoundation capabilities
4. Set up `@main` app entry with `DependencyContainer` and `.modelContainer`
5. Add Costco theme assets and app icon
6. Verify build compiles

---

## Task 2: Core Types

**Files:**  
`Core/Domain/Models/Receipt.swift`,  
`Core/Domain/Models/AuditData.swift`,  
`Core/Domain/Models/LineItem.swift`,  
`Core/Utilities/AppConstants.swift`,  
`Core/Theme/CostcoTheme.swift`

**Steps:**
1. Define `Receipt` (id, barcode, storeName, totalAmount, lineItems, imageID, etc.)
2. Define `AuditData` (receiptID, staffName, auditorName, issues, notes, status)
3. Define `LineItem` (itemNumber, description, quantity, price)
4. Add `AuditStatus` (.pending, .completed) and validation logic
5. Add sample data and preview helpers
6. Export via `DependencyContainer` and environment

---

## Task 3: Persistence

**Files:**  
`Core/Infrastructure/Persistence/SwiftDataRepositories.swift`,  
`Core/Domain/Repositories/ReceiptRepository.swift`,  
`Core/Domain/Repositories/AuditRepository.swift`,  
`Core/Domain/Repositories/ImageRepository.swift`

**Steps:**
1. Define SwiftData schema: `ReceiptEntity`, `AuditEntity`, `ImageEntity`
2. Implement mappers between domain models and entities
3. Implement `SwiftDataReceiptRepository`, `SwiftDataAuditRepository`, `SwiftDataImageRepository`
4. Wire repositories into `DependencyContainer` with `ModelContext`
5. Verify save/load round-trip for receipts and audits

---

## Task 4: Core Logic

**Files:**  
`Core/Domain/UseCases/ProcessReceiptUseCase.swift`,  
`Core/Domain/UseCases/SaveAuditUseCase.swift`,  
`Core/Domain/UseCases/DeleteReceiptUseCase.swift`,  
`Core/Domain/UseCases/FetchReceiptsUseCase.swift`,  
`Core/Domain/UseCases/ExportAuditsUseCase.swift`,  
`Core/Infrastructure/Services/VisionOCRService.swift`,  
`Core/Infrastructure/Services/CostcoReceiptParser.swift`,  
`Core/Infrastructure/Services/VisionBarcodeService.swift`

**Steps:**
1. Implement OCR via Vision `VNRecognizeTextRequest`
2. Implement barcode scanning via `VNDetectBarcodesRequest`
3. Implement `CostcoReceiptParser` to extract fields from raw text
4. Implement `ProcessReceiptUseCase` (OCR → parse → save receipt + image)
5. Implement `SaveAuditUseCase`, `DeleteReceiptUseCase`, `FetchReceiptsUseCase`, `ExportAuditsUseCase`
6. Write/verify use case behavior (failing tests optional; manual smoke test acceptable)

---

## Task 5: UI / Features

**Files:**  
`ContentView.swift`,  
`Features/Audit/Presentation/Views/AuditFormView.swift`,  
`Features/ReceiptCapture/Presentation/Views/ReceiptCameraView.swift`,  
`Features/Export/Presentation/Views/ExportView.swift`,  
`Features/Audit/Presentation/Views/MainTabView.swift`

**Steps:**
1. Scaffold `ContentView` with stats, capture button, today’s receipts list
2. Implement `ReceiptCameraView` with AVCaptureSession and receipt detection
3. Implement `AuditFormView` for staff name, auditor, item count, issues, notes
4. Implement `ExportView` and CSV generation for audits
5. Wire ViewModels (`ReceiptCaptureViewModel`, `AuditFormViewModel`, `ExportViewModel`) to use cases
6. Add `MainTabView` (Scan, Receipts, Export) if desired
7. Add `ReceiptsListView` with filter/search and swipe-to-delete

---

## Verification Checklist

1. **Install** — Open in Xcode, resolve packages if any, no build errors
2. **Build** — Compiles clean for iOS simulator/device
3. **Test** — Run app in simulator
4. **Run** — App starts with Door Audit home screen
5. **Smoke test** — Capture a receipt (camera or library) → navigate to audit form → fill staff name → save → export CSV and confirm data appears

---

## Notes

- **App entry:** `DoorAuditApp.swift` references `L1_DemoApp` internally; consider renaming to `DoorAuditApp` for consistency.
- **Debug logging:** `ContentView` contains inline agent log code for swipe delete; remove or guard with `#if DEBUG` before release.
- **Store config:** `AppConstants.Store` holds warehouse/store name; ensure it’s set per deployment if needed.
