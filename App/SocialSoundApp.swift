import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SocialSoundApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var spotifyAuth = SpotifyAuthManager.shared
    @StateObject private var broadcast = BroadcastManager()
    @StateObject private var locationService = LocationService()
    @StateObject private var currentUserStore = CurrentUserStore()
    @StateObject private var onboardingState = OnboardingStateManager()
    @StateObject private var notificationService = BroadcastNotificationService()
    @StateObject private var likeNotificationService = LikeNotificationService()

    init() {
        // Give URLSession.shared (used by AsyncImage) a real memory + disk cache
        // so album art and profile photos aren't re-downloaded on every scroll.
        URLCache.shared = URLCache(
            memoryCapacity: 32 * 1024 * 1024,   // 32 MB
            diskCapacity: 256 * 1024 * 1024     // 256 MB
        )

        // Firebase is configured here (before AppDelegate's didFinishLaunching)
        // so that all @StateObject services can use Firestore immediately.
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
            print("🔥 Firebase configured")
        }
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
            .preferredColorScheme(.dark) // Dark-first: lock the whole app to dark.
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

