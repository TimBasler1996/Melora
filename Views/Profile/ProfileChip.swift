//
//  ProfileChip.swift
//  SocialSound
//
//  Created by Tim Basler on 14.01.2026.
//


import SwiftUI

struct ProfileChip: View {
    let text: String
    let icon: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(AppColors.tintedBackground.opacity(0.5)))
        .foregroundColor(AppColors.primaryText)
    }
}
