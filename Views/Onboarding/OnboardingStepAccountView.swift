import SwiftUI
import AuthenticationServices

/// Last onboarding step: offer to attach the freshly created profile to an
/// Apple ID so it survives a reinstall. Skippable; the same option lives in
/// Settings.
struct OnboardingStepAccountView: View {
    @ObservedObject var viewModel: OnboardingViewModel
    @StateObject private var account = AccountService.shared
    @EnvironmentObject private var broadcast: BroadcastManager

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Keep your profile")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(AppColors.primaryText)

                Text("Right now your profile lives only on this phone. Sign in with Apple to keep it if you reinstall or switch devices.")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(AppColors.secondaryText)
            }

            VStack(alignment: .leading, spacing: 12) {
                benefitRow(icon: "iphone.and.arrow.forward", text: "Your photos, chats and followers move with you")
                benefitRow(icon: "eye.slash", text: "Apple shares nothing with us except a private ID")
                benefitRow(icon: "clock.arrow.circlepath", text: "You can do this later in Settings")
            }
            .padding(18)
            .melCard(cornerRadius: AppLayout.cornerRadiusLarge)

            SignInWithAppleButton(.continue) { request in
                account.prepareAppleRequest(request)
            } onCompletion: { result in
                Task { await viewModel.completeAppleSignIn(result, using: account, stopping: broadcast) }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 54)
            .clipShape(Capsule())
            .disabled(viewModel.isLinkingAccount)
            .opacity(viewModel.isLinkingAccount ? 0.6 : 1)

            if let msg = viewModel.accountErrorMessage, !msg.isEmpty {
                Text(msg)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
    }

    private func benefitRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(AppColors.live)
                .frame(width: 24)
            Text(text)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(AppColors.primaryText)
        }
    }
}
