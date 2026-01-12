import SwiftUI

struct OnboardingStepSpotifyView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

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

            if viewModel.isSpotifyProfileLinked {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.primary)

                    Text("Spotify connected")
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)
                }
            } else {
                let buttonTitle = viewModel.isConnectingSpotify
                    ? "Connecting…"
                    : (viewModel.isSpotifyConnected ? "Sync Spotify profile" : "Connect Spotify")

                Button(action: {
                    viewModel.startSpotifyAuth()
                }) {
                    HStack(spacing: 8) {
                        if viewModel.isConnectingSpotify {
                            ProgressView()
                                .tint(.white)
                        }

                        Text(buttonTitle)
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.primary)
                    .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
                }
                .disabled(viewModel.isConnectingSpotify)
                .opacity(viewModel.isConnectingSpotify ? 0.7 : 1)
            }

            if let error = viewModel.spotifyErrorMessage, !error.isEmpty {
                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.red.opacity(0.85))
            }

            if let finishError = viewModel.finishErrorMessage, !finishError.isEmpty {
                Text(finishError)
                    .font(AppFonts.footnote())
                    .foregroundColor(.red.opacity(0.85))
            }
        }
        .onChange(of: spotifyAuth.isAuthorized) { isAuthorized in
            viewModel.updateSpotifyConnection(isAuthorized)
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
