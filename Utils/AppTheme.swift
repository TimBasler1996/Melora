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

    // MARK: - Brand ("Ember")

    /// Ember: live, and the one primary action per screen. Nothing else.
    /// #FF5A3C
    static let primary = Color(hex: 0xFF5A3C)

    /// Slate: recently live, muted states.
    static let secondary = Color(hex: 0x6E6A78)

    /// Live is Ember too; the dot with rings is the mark of being on air.
    static let live = Color(hex: 0xFF5A3C)

    static let destructive = Color(hex: 0xFF5A3C)

    // MARK: - Surfaces (warm "vinyl" black, never blue)

    static let background = Color(hex: 0x0E0C0B)
    static let backgroundElevated = Color(hex: 0x171412)
    static let surface = Color(hex: 0xF4EFE6).opacity(0.06)
    static let surfaceElevated = Color(hex: 0xF4EFE6).opacity(0.09)
    static let stroke = Color(hex: 0xF4EFE6).opacity(0.10)
    static let cardBackground = Color(hex: 0x171412)
    static let tintedBackground = Color.black.opacity(0.25)

    // MARK: - Text (cream, not white)

    static let primaryText = Color(hex: 0xF4EFE6)
    static let secondaryText = Color(hex: 0xF4EFE6).opacity(0.62)
    static let mutedText = Color(hex: 0xF4EFE6).opacity(0.40)
}

enum AppLayout {
    static let cornerRadiusLarge: CGFloat = 20
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusSmall: CGFloat = 8

    static let cardPadding: CGFloat = 16
    static let screenPadding: CGFloat = 20

    static let shadowRadius: CGFloat = 16
    static let shadowOpacity: Double = 0.15
}

/// Two voices: a plain, heavy grotesk for names and UI, and an italic serif
/// reserved for song titles. That contrast is the app's signature.
///
/// Both come from the system (SF Pro and New York) so nothing has to be
/// bundled; swap `Font.system` for `Font.custom("Archivo", ...)` /
/// `Font.custom("InstrumentSerif-Italic", ...)` here once the font files
/// are added to the project.
enum AppFonts {
    static func largeTitle() -> Font { .system(size: 30, weight: .heavy) }
    static func title() -> Font { .system(size: 24, weight: .bold) }
    static func sectionTitle() -> Font { .system(size: 20, weight: .bold) }
    static func headline() -> Font { .system(size: 16, weight: .semibold) }
    static func body() -> Font { .system(size: 15, weight: .medium) }
    static func subheadline() -> Font { .system(size: 14, weight: .semibold) }
    static func footnote() -> Font { .system(size: 13, weight: .medium) }
    static func caption() -> Font { .system(size: 11, weight: .medium) }

    /// Song titles only.
    static func song(size: CGFloat) -> Font {
        .system(size: size, weight: .regular, design: .serif).italic()
    }
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
