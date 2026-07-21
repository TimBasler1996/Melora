//
//  AppTheme.swift
//  SocialSound
//
//  Created by Tim Basler on 14.11.2025.
//


import SwiftUI

/// Centralized design system for the SocialSound (Melora) app.
///
/// This is the single source of truth for appearance. The app is **dark-first**:
/// every color below is a fixed dark token — nothing adapts to Light Mode — and
/// the root locks `.preferredColorScheme(.dark)`.
enum AppTheme {

    /// The standard screen background shared by every main screen. Replaces the
    /// ad-hoc per-screen gradients that used to live in Chat / Likes / Nearby.
    static var screenBackground: LinearGradient {
        LinearGradient(
            colors: [AppColors.backgroundElevated, AppColors.background],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

/// Color palette used throughout the app. All values are fixed dark tokens.
enum AppColors {

    // MARK: - Brand

    /// Primary accent color for key actions (broadcast button, active tab, sent bubbles).
    /// #5B46F5
    static let primary = Color(red: 0.357, green: 0.275, blue: 0.961)

    /// Secondary accent (subtle highlights, gradients).
    static let secondary = Color(red: 0.15, green: 0.75, blue: 0.95)

    /// The one and only live / broadcast green. #1ACC66
    /// Replaces every hardcoded `Color(red: 0.2, green: 0.85, blue: 0.4)` in the codebase.
    static let live = Color(red: 0.10, green: 0.80, blue: 0.40)

    /// Color used for destructive actions (stop, errors).
    static let destructive = Color.red

    // MARK: - Backgrounds (dark, fixed)

    /// Near-black base background for screens. #08080C
    static let background = Color(hex: 0x08080C)

    /// Top of the standard screen gradient. #15151D
    static let backgroundElevated = Color(hex: 0x15151D)

    /// Standard card / surface fill sitting on the background.
    static let surface = Color.white.opacity(0.06)

    /// Slightly brighter surface for elevated cards / received chat bubbles.
    static let surfaceElevated = Color.white.opacity(0.09)

    /// Hairline stroke used around cards and surfaces.
    static let stroke = Color.white.opacity(0.10)

    /// Legacy alias — old code referenced `cardBackground`; routes to `surface`.
    static let cardBackground = surface

    /// A slightly tinted background used behind artwork / inside input fields.
    static let tintedBackground = Color.black.opacity(0.25)

    // MARK: - Text

    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.62)
    static let mutedText = Color.white.opacity(0.40)
}

/// Layout constants (spacing, corner radii, etc.).
enum AppLayout {
    static let cornerRadiusLarge: CGFloat = 24
    static let cornerRadiusMedium: CGFloat = 16
    static let cornerRadiusSmall: CGFloat = 10

    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 20

    static let shadowRadius: CGFloat = 16
    static let shadowOpacity: Double = 0.15
}

/// Locked type ramp. Everything is rounded (the app's chosen voice); no view
/// should hardcode `.system(size:)` for a standard text role anymore.
enum AppFonts {
    static func largeTitle() -> Font { .system(size: 28, weight: .bold, design: .rounded) }
    static func title() -> Font { .system(size: 24, weight: .bold, design: .rounded) }
    static func sectionTitle() -> Font { .system(size: 20, weight: .semibold, design: .rounded) }
    static func headline() -> Font { .system(size: 16, weight: .semibold, design: .rounded) }
    static func body() -> Font { .system(size: 15, weight: .medium, design: .rounded) }
    static func subheadline() -> Font { .system(size: 14, weight: .semibold, design: .rounded) }
    static func footnote() -> Font { .system(size: 13, weight: .medium, design: .rounded) }
    static func caption() -> Font { .system(size: 11, weight: .medium, design: .rounded) }
}

// MARK: - Reusable View Modifiers

/// Lays `AppTheme.screenBackground.ignoresSafeArea()` behind content so every
/// screen shares one background treatment.
struct MelScreenBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(AppTheme.screenBackground.ignoresSafeArea())
    }
}

/// Standard card treatment: `AppColors.surface` fill, 1px `AppColors.stroke`
/// border, medium corner radius. Stops cards from being redefined per-view.
struct MelCard: ViewModifier {
    var cornerRadius: CGFloat = AppLayout.cornerRadiusMedium

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.stroke, lineWidth: 1)
            )
    }
}

extension View {
    /// Lays the shared screen background behind the content.
    func melScreenBackground() -> some View {
        modifier(MelScreenBackground())
    }

    /// Applies the standard card surface + stroke.
    func melCard(cornerRadius: CGFloat = AppLayout.cornerRadiusMedium) -> some View {
        modifier(MelCard(cornerRadius: cornerRadius))
    }
}

// MARK: - Color(hex:)

extension Color {
    /// Creates a color from a 24-bit RGB hex value, e.g. `Color(hex: 0x15151D)`.
    init(hex: UInt, alpha: Double = 1.0) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >> 8) & 0xFF) / 255.0
        let b = Double(hex & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}
