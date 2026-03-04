import SwiftUI

struct OnboardingFlowPlaceholderView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack {
                Spacer()

                VStack(spacing: 12) {
                    Text("Welcome to SocialSound")
                        .font(AppFonts.title())
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)

                    Text("Create your profile to get started")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)

                    Button(action: {}) {
                        Text("Start onboarding")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.primaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .background(Color.white.opacity(0.22))
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
                }
                .padding(AppLayout.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                        .fill(AppColors.cardBackground.opacity(0.98))
                )
                .shadow(color: Color.black.opacity(AppLayout.shadowOpacity), radius: AppLayout.shadowRadius, x: 0, y: 10)
                .padding(.horizontal, AppLayout.screenPadding)

                Spacer()
            }
        }
    }
}

#Preview {
    OnboardingFlowPlaceholderView()
}
