import SwiftUI
import UIKit

struct OnboardingFlowView: View {
    @EnvironmentObject private var onboardingState: OnboardingStateManager
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

    @StateObject private var viewModel = OnboardingViewModel()

    var body: some View {
        ZStack {
            // Dark gradient background matching NowPlayingView and LikesInboxView
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.2),
                    Color.black.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                contentArea
                Spacer(minLength: 20)
                bottomCTA
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.stepIndex)
        .contentShape(Rectangle())
        .onTapGesture { hideKeyboard() }
        .onChange(of: viewModel.didFinish) { _, finished in
            if finished {
                onboardingState.reload()
            }
        }
    }

    private var topBar: some View {
        VStack(spacing: 12) {
            HStack {
                Button(action: viewModel.goBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                        )
                }
                .opacity(viewModel.stepIndex == 1 ? 0 : 1)
                .disabled(viewModel.stepIndex == 1)

                Spacer()

                Text(viewModel.progressText)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    Capsule()
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                        .frame(width: geo.size.width * viewModel.progressValue, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progressValue)
                }
            }
            .frame(height: 4)
        }
    }

    private var contentArea: some View {
        VStack(spacing: 16) {
            switch viewModel.stepIndex {
            case 1:
                OnboardingStepBasicsView(viewModel: viewModel)
            case 2:
                OnboardingStepPhotosView(viewModel: viewModel)
            case 3:
                OnboardingStepSpotifyView(viewModel: viewModel)
            default:
                OnboardingStepBasicsView(viewModel: viewModel)
            }
        }
        .padding(.top, 24)
    }

    private var bottomCTA: some View {
        VStack(spacing: 10) {
            if viewModel.stepIndex < 3 {
                let isEnabled = viewModel.canContinueCurrentStep
                Button(action: viewModel.goNext) {
                    Text(viewModel.stepIndex == 1 ? "Looks good" : "Continue")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                                .opacity(isEnabled ? 1 : 0.4)
                        )
                }
                .disabled(!isEnabled)
            } else {
                // Step 3
                if viewModel.spotifyConnected == false {
                    Button {
                        Task { await viewModel.connectSpotify(using: spotifyAuth) }
                    } label: {
                        Text(viewModel.isConnectingSpotify ? "Connecting…" : "Connect Spotify")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                            )
                    }
                    .disabled(viewModel.isConnectingSpotify)
                    .opacity(viewModel.isConnectingSpotify ? 0.6 : 1)
                } else {
                    Button {
                        Task { await viewModel.finish(using: spotifyAuth) }
                    } label: {
                        Text(viewModel.isFinishing ? "Finishing…" : "Finish")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                Capsule()
                                    .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                                    .opacity(viewModel.canFinish ? 1 : 0.4)
                            )
                    }
                    .disabled(!viewModel.canFinish)
                }
            }

            if let msg = viewModel.spotifyErrorMessage, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            if let msg = viewModel.finishErrorMessage, !msg.isEmpty {
                Text(msg)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 6)
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
