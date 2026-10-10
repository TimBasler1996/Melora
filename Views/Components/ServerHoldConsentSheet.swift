import SwiftUI

/// Asked once, before the server is ever allowed to hold a live session.
///
/// The ask is specific on purpose. Melora cannot keep a broadcast alive from
/// the background, so without this the session ends minutes after the phone
/// goes into a pocket — which is the normal way to listen. The alternative
/// is the server checking Spotify on the user's behalf, and that is a real
/// thing to agree to, not a line to bury in a policy.
struct ServerHoldConsentSheet: View {
    let onAllow: () -> Void
    let onDecline: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                LiveRipple(size: 90)
                    .padding(.top, 28)

                VStack(spacing: 10) {
                    Text("Stay live with the app closed?")
                        .font(AppFonts.largeTitle())
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)

                    Text("Melora can’t see what you’re playing while it’s closed. If you let it, our server asks Spotify for you — so you stay in other people’s Discover with the phone in your pocket.")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 14) {
                    row("pause", "Two hours, then it stops", "Every session ends by itself. Go live again whenever you want.")
                    row("hand", "Only while you’re live", "Nothing is checked before you tap Go live or after you stop.")
                    row("trash", "Stopping deletes it", "The connection to your Spotify is removed, not just switched off.")
                    row("pin", "Your position stays where you started", "The server never learns a new one while the app is closed.")
                }
                .padding(18)
                .melCard(cornerRadius: AppLayout.cornerRadiusLarge)

                VStack(spacing: 10) {
                    Button {
                        onAllow()
                        dismiss()
                    } label: {
                        Text("Stay live in the background")
                            .font(.system(size: 17, weight: .heavy))
                            .foregroundColor(AppColors.background)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(Capsule().fill(AppColors.primary))
                    }
                    .buttonStyle(.pressable)

                    Button {
                        onDecline()
                        dismiss()
                    } label: {
                        Text("Only while the app is open")
                            .font(AppFonts.subheadline())
                            .foregroundColor(AppColors.secondaryText)
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }

                Text("You can change this any time in Settings.")
                    .font(AppFonts.caption())
                    .foregroundColor(AppColors.mutedText)
                    .padding(.bottom, 20)
            }
            .padding(.horizontal, AppLayout.screenPadding)
        }
        .scrollIndicators(.hidden)
        .presentationBackground(AppColors.background)
        .presentationDragIndicator(.visible)
    }

    private func row(_ icon: String, _ title: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            MIcon(icon, size: 18, color: AppColors.primary)
                .frame(width: 24)
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
    Color.black.sheet(isPresented: .constant(true)) {
        ServerHoldConsentSheet(onAllow: {}, onDecline: {})
    }
}
