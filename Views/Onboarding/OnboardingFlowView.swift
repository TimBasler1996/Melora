import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                contentCard
                Spacer()
                ctaButton
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.stepIndex)
        .contentShape(Rectangle())
        .onTapGesture {
            hideKeyboard()
        }
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: viewModel.goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 36, height: 36)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .opacity(viewModel.stepIndex == 1 ? 0 : 1)
                .disabled(viewModel.stepIndex == 1)

                Spacer()

                Text(viewModel.progressText)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.9))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.2))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color.white.opacity(0.9))
                        .frame(width: geo.size.width * viewModel.progressValue, height: 4)
                }
            }
            .frame(height: 4)
        }
    }

    private var contentCard: some View {
        VStack(spacing: 16) {
            switch viewModel.stepIndex {
            case 1:
                OnboardingStepBasicsView(viewModel: viewModel)
            default:
                VStack(alignment: .leading, spacing: 8) {
                    Text("Next step")
                        .font(AppFonts.title())
                        .foregroundColor(AppColors.primaryText)

                    Text("Photos and Spotify connection will be added next.")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.secondaryText)
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
        )
        .shadow(color: Color.black.opacity(AppLayout.shadowOpacity), radius: AppLayout.shadowRadius, x: 0, y: 10)
        .padding(.top, 24)
    }

    private var ctaButton: some View {
        Button(action: viewModel.goNext) {
            Text("Continue")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(AppColors.primary)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous))
        }
        .disabled(!viewModel.canContinue)
        .opacity(viewModel.canContinue ? 1 : 0.6)
        .padding(.bottom, 6)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

#Preview {
    OnboardingFlowView()
}
