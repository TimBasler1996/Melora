import SwiftUI

struct OnboardingStepSpotifyView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect Spotify")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("SocialSound needs Spotify to show what you're listening to.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)

            VStack(alignment: .leading, spacing: 10) {
                featureRow("Broadcast your current track")
                featureRow("Discover people nearby with similar taste")
                featureRow("Likes as lightweight social signals")
            }

            if let error = viewModel.spotifyErrorMessage, !error.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error)
                        .font(AppFonts.footnote())
                        .foregroundColor(.red.opacity(0.85))

                    Button(action: {
                        Task { await viewModel.connectSpotify() }
                    }) {
                        Text("Try again")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(AppColors.primaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.18))
                            .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusSmall, style: .continuous))
                    }
                    .disabled(viewModel.isConnectingSpotify)
                    .opacity(viewModel.isConnectingSpotify ? 0.6 : 1)
                }
            }

            if let finishError = viewModel.finishErrorMessage, !finishError.isEmpty {
                Text(finishError)
                    .font(AppFonts.footnote())
                    .foregroundColor(.red.opacity(0.85))
            }
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(AppColors.primary)

            Text(text)
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.secondaryText)
        }
    }
}

#Preview {
    OnboardingStepSpotifyView(viewModel: OnboardingViewModel())
        .padding()
}
