//
//  AppTheme.swift
//  SocialSound
//
//  Created by Tim Basler on 14.11.2025.
//


import SwiftUI

/// Centralized design system for the SocialSound app.
enum AppTheme { }

/// Color palette used throughout the app.
enum AppColors {
    // MARK: - Brand
    
    /// Primary accent color for key actions (e.g., broadcast button, active tab).
    static let primary = Color(red: 0.35, green: 0.27, blue: 0.95)   // Purple-ish
    
    /// Secondary accent (e.g. for subtle highlights).
    static let secondary = Color(red: 0.15, green: 0.75, blue: 0.95) // Cyan-ish
    
    /// Color used to indicate an active / live broadcast.
    static let live = Color(red: 0.10, green: 0.80, blue: 0.40)      // Green
    
    /// Color used for destructive actions (stop, errors).
    static let destructive = Color.red
    
    // MARK: - Backgrounds
    
    /// Main background for screens.
    static let background = Color(.systemBackground)
    
    /// Background for cards / surfaces that sit on top of the main background.
    static let cardBackground = Color(.secondarySystemBackground)
    
    /// A slightly tinted background that can be used behind artwork.
    static let tintedBackground = Color.black.opacity(0.25)
    
    // MARK: - Text
    
    static let primaryText = Color.primary
    static let secondaryText = Color.secondary
    static let mutedText = Color.gray
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

/// Font helpers for a consistent text hierarchy.
enum AppFonts {
    static func title() -> Font {
        .system(size: 28, weight: .bold, design: .rounded)
    }
    
    static func sectionTitle() -> Font {
        .system(size: 20, weight: .semibold, design: .rounded)
    }
    
    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .default)
    }
    
    static func footnote() -> Font {
        .system(size: 13, weight: .regular, design: .default)
    }
}
