//
//  View+Extensions.swift
//  L1 Demo
//
//  SwiftUI View extension helpers
//  Created: December 2025
//

import SwiftUI

extension View {
    
    // MARK: - Conditional Modifiers
    
    /// Apply modifier conditionally
    @ViewBuilder
    func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// Apply one of two modifiers based on condition
    @ViewBuilder
    func `if`<TrueContent: View, FalseContent: View>(
        _ condition: Bool,
        if ifTransform: (Self) -> TrueContent,
        else elseTransform: (Self) -> FalseContent
    ) -> some View {
        if condition {
            ifTransform(self)
        } else {
            elseTransform(self)
        }
    }
    
    // MARK: - Loading & Overlay
    
    /// Show loading overlay
    func loading(_ isLoading: Bool) -> some View {
        overlay {
            if isLoading {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                }
            }
        }
    }
    
    /// Show error alert
    func errorAlert(
        error: Binding<Error?>,
        buttonTitle: String = "OK"
    ) -> some View {
        alert(
            "Error",
            isPresented: Binding(
                get: { error.wrappedValue != nil },
                set: { if !$0 { error.wrappedValue = nil } }
            ),
            presenting: error.wrappedValue
        ) { _ in
            Button(buttonTitle, role: .cancel) {
                error.wrappedValue = nil
            }
        } message: { err in
            Text(err.localizedDescription)
        }
    }
    
    // MARK: - Keyboard
    
    /// Hide keyboard
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }
    
    /// Dismiss keyboard on tap
    func dismissKeyboardOnTap() -> some View {
        onTapGesture {
            hideKeyboard()
        }
    }
    
    // MARK: - Navigation
    
    /// Navigate to destination when condition is true
    /// Uses navigationDestination for iOS 16+ NavigationStack compatibility
    @available(iOS, deprecated: 16.0, message: "Use NavigationStack with navigationDestination modifier instead")
    func navigate<Destination: View>(
        when condition: Binding<Bool>,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        background {
            NavigationLink(
                isActive: condition,
                destination: destination,
                label: { EmptyView() }
            )
            .hidden()
        }
    }
    
    // MARK: - Corner Radius
    
    /// Apply corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
    
    // MARK: - Sizing
    
    /// Set frame with same width and height
    func frame(size: CGFloat, alignment: Alignment = .center) -> some View {
        frame(width: size, height: size, alignment: alignment)
    }
    
    /// Fill available space
    func fillWidth(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }
    
    func fillHeight(alignment: Alignment = .center) -> some View {
        frame(maxHeight: .infinity, alignment: alignment)
    }
    
    func fill(alignment: Alignment = .center) -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
    }
    
    // MARK: - Animations
    
    /// Animate with spring
    func animateWithSpring(value: some Equatable) -> some View {
        animation(CostcoTheme.Animation.spring, value: value)
    }
    
    /// Animate with standard easing
    func animateWithEasing(value: some Equatable) -> some View {
        animation(CostcoTheme.Animation.standard, value: value)
    }
    
    // MARK: - Shadows
    
    /// Apply shadow from theme
    func shadow(_ style: CostcoTheme.ShadowStyle) -> some View {
        shadow(
            color: style.color,
            radius: style.radius,
            x: style.x,
            y: style.y
        )
    }
}

// MARK: - Rounded Corner Shape

private struct RoundedCorner: Shape {
    let radius: CGFloat
    let corners: UIRectCorner
    
    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}

// MARK: - Preview Helper

#if DEBUG
extension View {
    /// Wrap view for preview with common setup
    func previewSetup(
        displayName: String? = nil,
        padding: CGFloat = 20
    ) -> some View {
        self
            .padding(padding)
            .previewDisplayName(displayName ?? "Preview")
    }
}
#endif
