//
//  OnboardingStepSpotifyView 2.swift
//  SocialSound
//
//  Created by Tim Basler on 12.01.2026.
//


import SwiftUI

struct Onboa    rdingStepSpotifyView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Connect Spotify")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("This step will be implemented next (Spotify is mandatory).")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)
        }
    }
}

#Preview {
    OnboardingStepSpotifyView()
        .padding()
}
