import SwiftUI

/// First screen a new user sees: what Melora is, in one breath.
struct OnboardingWelcomeView: View {
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)

            VStack(spacing: 18) {
                RippleMark(size: 112)

                MeloraWordmark(size: 44)

                Text("Share what you’re playing.\nMeet the people around you through music.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColors.secondaryText)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 16) {
                row(icon: "music.note", title: "Go live", text: "Broadcast the track you’re playing on Spotify to people nearby.")
                row(icon: "location", title: "Discover", text: "See who is live around you and what they’re listening to.")
                row(icon: "heart", title: "Connect", text: "Like a track, send a message, start a chat.")
            }
            .padding(.top, 36)

            Spacer(minLength: 24)

            Button(action: onContinue) {
                Text("Get started")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Capsule().fill(AppColors.live))
            }

            Text("No account needed. You can keep your profile with Apple later.")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
        }
    }

    private func row(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(AppColors.live)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)
                Text(text)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#Preview {
    OnboardingWelcomeView(onContinue: {})
        .padding(20)
        .melScreenBackground()
}
