import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SocialSoundApp: App {

    @StateObject private var spotifyAuth = SpotifyAuthManager.shared
    @StateObject private var broadcast = BroadcastManager()
    @StateObject private var locationService = LocationService()
    @StateObject private var currentUserStore = CurrentUserStore()
    @StateObject private var onboardingState = OnboardingStateManager()
    @StateObject private var notificationService = BroadcastNotificationService()
    @StateObject private var likeNotificationService = LikeNotificationService()

    init() {
        FirebaseApp.configure()
        print("🔥 Firebase configured")
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                if onboardingState.isLoading {
                    LoadingView()
                        .transition(.opacity)
                } else if onboardingState.needsOnboarding {
                    OnboardingFlowView()
                        .environmentObject(onboardingState)
                        .transition(.opacity)
                } else {
                    MainView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.25), value: onboardingState.isLoading)
            .animation(.easeInOut(duration: 0.25), value: onboardingState.needsOnboarding)
            .onAppear {
                FirebaseAuthBootstrap.ensureFirebaseUser()
                currentUserStore.startListening()
                locationService.requestAuthorizationIfNeeded()
                notificationService.start(locationService: locationService)
                likeNotificationService.start()
            }
            .environmentObject(spotifyAuth)
            .environmentObject(broadcast)
            .environmentObject(locationService)
            .environmentObject(currentUserStore)
        }
    }
}

private struct LoadingView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ProgressView("Loading…")
                .tint(.white)
                .foregroundColor(.white)
        }
    }
}

