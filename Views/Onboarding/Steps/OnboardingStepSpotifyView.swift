import SwiftUI

struct OnboardingStepSpotifyView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Connect Spotify")
                .font(AppFonts.title())
                .foregroundColor(AppColors.primaryText)

            Text("Spotify is required so others can see what you’re listening to.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.secondaryText)

            VStack(spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: viewModel.spotifyConnected ? "checkmark.seal.fill" : "music.note.list")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(viewModel.spotifyConnected ? .green : AppColors.primaryText)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(viewModel.spotifyConnected ? "Spotify connected" : "Not connected yet")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.primaryText)

                        Text(viewModel.spotifyConnected ? "You’re ready to finish." : "Tap Connect Spotify below to continue.")
                            .font(AppFonts.footnote())
                            .foregroundColor(AppColors.secondaryText)
                    }

                    Spacer()
                }
                .padding(14)
                .background(AppColors.tintedBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))

                if viewModel.isConnectingSpotify {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text("Waiting for Spotify authorization…")
                            .font(AppFonts.footnote())
                            .foregroundColor(AppColors.secondaryText)
                        Spacer()
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}

