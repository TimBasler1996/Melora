import SwiftUI

struct OnboardingStepSpotifyView: View {
    @ObservedObject var viewModel: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connect Spotify")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)

                Text("Connect your Spotify account to share your music taste with matches.")
                    .font(.system(size: 17, weight: .medium, design: .rounded))
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
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.primaryText)

                        Text("Your Spotify account is connected")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    } else {
                        Text("Not Connected")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.primaryText)

                        Text("Connect now, or skip and do it later")
                            .font(AppFonts.body())
                            .foregroundColor(AppColors.secondaryText)
                            .multilineTextAlignment(.center)
                    }
                }

                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(
                        icon: "music.note.list",
                        title: "Share your music taste",
                        description: "Let matches see what you're listening to"
                    )

                    FeatureRow(
                        icon: "person.2.fill",
                        title: "Find music compatibility",
                        description: "Match with people who share your taste"
                    )

                    FeatureRow(
                        icon: "lock.fill",
                        title: "Your data is private",
                        description: "We only access your basic profile info"
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
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
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
