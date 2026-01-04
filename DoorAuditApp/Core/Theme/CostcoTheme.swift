//
//  CostcoTheme.swift
//  L1 Demo
//
//  Centralized design system for Costco branding
//  Single source of truth for all colors, typography, spacing
//  Created: December 2025
//

import SwiftUI

enum CostcoTheme {
    
    // MARK: - Colors
    
    enum Colors {
        // Primary Costco branding colors
        static let primary = Color(red: 0.0, green: 0.318, blue: 0.612)      // Costco Blue #005199
        static let primaryDark = Color(red: 0.0, green: 0.235, blue: 0.451)  // Darker Blue #003C73
        static let primaryLight = Color(red: 0.2, green: 0.518, blue: 0.812) // Lighter Blue #3384CF
        
        // Secondary Costco colors
        static let secondary = Color(red: 0.863, green: 0.078, blue: 0.235)  // Costco Red #DC143C
        static let secondaryDark = Color(red: 0.643, green: 0.058, blue: 0.176) // Darker Red #A40F2D
        static let secondaryLight = Color(red: 1.0, green: 0.298, blue: 0.435) // Lighter Red #FF4C6F
        
        // Neutral colors
        static let background = Color(UIColor.systemGroupedBackground)
        static let cardBackground = Color(UIColor.systemBackground)
        static let textPrimary = Color(UIColor.label)
        static let textSecondary = Color(UIColor.secondaryLabel)
        static let textTertiary = Color(UIColor.tertiaryLabel)
        static let divider = Color(UIColor.separator)
        
        // Semantic colors
        static let success = Color.green
        static let warning = Color.orange
        static let error = Color.red
        static let info = primary
        
        // Status colors
        static let pending = Color.orange
        static let completed = Color.green
        static let issue = Color.red
        static let inProgress = primary
    }
    
    // MARK: - Typography
    
    enum Typography {
        // Headings
        static let largeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
        static let title = Font.system(size: 28, weight: .bold, design: .rounded)
        static let title2 = Font.system(size: 22, weight: .bold, design: .rounded)
        static let title3 = Font.system(size: 20, weight: .semibold, design: .rounded)
        
        // Body text
        static let headline = Font.system(size: 17, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let callout = Font.system(size: 16, weight: .regular)
        static let subheadline = Font.system(size: 15, weight: .regular)
        static let footnote = Font.system(size: 13, weight: .regular)
        static let caption = Font.system(size: 12, weight: .regular)
        static let caption2 = Font.system(size: 11, weight: .regular)
        
        // Custom styles
        static let costcoHeader = Font.system(size: 32, weight: .black)
        static let costcoSubheader = Font.system(size: 14, weight: .bold)
        static let receiptNumber = Font.system(size: 20, weight: .bold, design: .monospaced)
        static let priceAmount = Font.system(size: 24, weight: .bold, design: .rounded)
    }
    
    // MARK: - Spacing
    
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
        
        // Semantic spacing
        static let cardPadding: CGFloat = md
        static let sectionSpacing: CGFloat = lg
        static let itemSpacing: CGFloat = sm
    }
    
    // MARK: - Corner Radius
    
    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let round: CGFloat = 999 // Fully rounded
        
        // Semantic radius
        static let card: CGFloat = md
        static let button: CGFloat = lg
        static let badge: CGFloat = round
    }
    
    // MARK: - Shadow
    
    struct ShadowStyle {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }
    
    enum Shadow {
        static let none = ShadowStyle(color: .clear, radius: 0, x: 0, y: 0)
        static let sm = ShadowStyle(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        static let md = ShadowStyle(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        static let lg = ShadowStyle(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        static let xl = ShadowStyle(color: .black.opacity(0.2), radius: 16, x: 0, y: 8)
    }
    
    // MARK: - Border
    
    enum Border {
        static let thin: CGFloat = 0.5
        static let regular: CGFloat = 1
        static let thick: CGFloat = 2
        static let bold: CGFloat = 3
        
        // Colors
        static let colorLight = Color.gray.opacity(0.2)
        static let colorMedium = Color.gray.opacity(0.4)
        static let colorDark = Color.gray.opacity(0.6)
    }
    
    // MARK: - Icons
    
    enum Icons {
        // Navigation
        static let home = "house.fill"
        static let list = "list.bullet"
        static let settings = "gearshape.fill"
        static let back = "chevron.left"
        static let forward = "chevron.right"
        static let close = "xmark"
        
        // Actions
        static let add = "plus"
        static let delete = "trash"
        static let edit = "pencil"
        static let save = "checkmark"
        static let cancel = "xmark"
        static let share = "square.and.arrow.up"
        static let export = "square.and.arrow.up.on.square"
        
        // Receipt related
        static let camera = "camera.fill"
        static let barcode = "barcode.viewfinder"
        static let receipt = "doc.text.fill"
        static let scan = "doc.text.viewfinder"
        
        // Status
        static let success = "checkmark.circle.fill"
        static let error = "xmark.circle.fill"
        static let warning = "exclamationmark.triangle.fill"
        static let info = "info.circle.fill"
        static let pending = "clock.fill"
        
        // Audit
        static let audit = "checkmark.seal.fill"
        static let issue = "exclamationmark.bubble.fill"
        static let note = "note.text"
        static let staff = "person.fill"
    }
    
    // MARK: - Animation
    
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: AppConstants.Animation.quick)
        static let standard = SwiftUI.Animation.easeInOut(duration: AppConstants.Animation.standard)
        static let slow = SwiftUI.Animation.easeInOut(duration: AppConstants.Animation.slow)
        static let spring = SwiftUI.Animation.spring(response: 0.3, dampingFraction: 0.7)
        static let bouncy = SwiftUI.Animation.spring(response: 0.4, dampingFraction: 0.6)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply Costco card style
    func costcoCard(padding: CGFloat = CostcoTheme.Spacing.cardPadding) -> some View {
        self
            .padding(padding)
            .background(CostcoTheme.Colors.cardBackground)
            .cornerRadius(CostcoTheme.CornerRadius.card)
            .shadow(
                color: CostcoTheme.Shadow.md.color,
                radius: CostcoTheme.Shadow.md.radius,
                x: CostcoTheme.Shadow.md.x,
                y: CostcoTheme.Shadow.md.y
            )
    }
    
    /// Apply Costco button style (primary)
    func costcoPrimaryButton() -> some View {
        self
            .font(CostcoTheme.Typography.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(CostcoTheme.Colors.secondary)
            .cornerRadius(CostcoTheme.CornerRadius.button)
    }
    
    /// Apply Costco button style (secondary)
    func costcoSecondaryButton() -> some View {
        self
            .font(CostcoTheme.Typography.headline)
            .foregroundColor(CostcoTheme.Colors.primary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(CostcoTheme.Colors.primary.opacity(0.1))
            .cornerRadius(CostcoTheme.CornerRadius.button)
            .overlay(
                RoundedRectangle(cornerRadius: CostcoTheme.CornerRadius.button)
                    .stroke(CostcoTheme.Colors.primary, lineWidth: CostcoTheme.Border.regular)
            )
    }
    
    /// Apply status badge style
    func statusBadge(color: Color) -> some View {
        self
            .font(CostcoTheme.Typography.caption2)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .padding(.horizontal, CostcoTheme.Spacing.sm)
            .padding(.vertical, CostcoTheme.Spacing.xs)
            .background(color)
            .cornerRadius(CostcoTheme.CornerRadius.badge)
    }
}

// MARK: - Color Extensions

extension Color {
    /// Initialize from hex string
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
