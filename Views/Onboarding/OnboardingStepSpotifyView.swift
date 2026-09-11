import SwiftUI

struct OnboardingStepSpotifyView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect Spotify")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.primaryText)

                Text("Melora shows the track you’re playing on Spotify when you go live.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColors.secondaryText)
            }

            // Connection status card
            VStack(spacing: 20) {
                // Spotify icon/status
                ZStack {
                    Circle()
                        .fill(viewModel.spotifyConnected ? AppColors.live.opacity(0.15) : AppColors.surface)
                        .frame(width: 100, height: 100)

                    if viewModel.spotifyConnected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50, weight: .semibold))
                            .foregroundColor(AppColors.live)
                    } else {
                        Image(systemName: "music.note")
                            .font(.system(size: 50, weight: .medium))
                            .foregroundColor(AppColors.mutedText)
                    }
                }
                .padding(.top, 16)

                // Status message
                VStack(spacing: 8) {
                    if viewModel.spotifyConnected {
                        Text("Connected")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.primaryText)

                        Text("You’re ready to go live")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Not Connected")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(AppColors.primaryText)

                        Text("Connect now, or skip and do it in Settings later. Without Spotify you can browse and chat, but not go live.")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }

                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        icon: "dot.radiowaves.left.and.right",
                        title: "Go live with what you play",
                        description: "People nearby see your current track while you’re live"
                    )

                    FeatureRow(
                        icon: "play.circle",
                        title: "Control playback from Melora",
                        description: "Play, pause and skip without leaving the app"
                    )

                    FeatureRow(
                        icon: "lock.fill",
                        title: "Nothing is posted to Spotify",
                        description: "We read your current track and profile picture, and never share your listening history"
                    )
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.live)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)

                Text(description)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
            }
        }
    }
}

#Preview {
    OnboardingStepSpotifyView(viewModel: OnboardingViewModel())
        .padding()
}
