//
//  OnboardingStepPhotosView 2.swift
//  SocialSound
//
//  Created by Tim Basler on 12.01.2026.
//


import SwiftUI

struct OnboardingStepPhotosView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add photos")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("This step will be implemented next (3 photos required).")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)
        }
    }
}

#Preview {
    OnboardingStepPhotosView()
        .padding()
}
