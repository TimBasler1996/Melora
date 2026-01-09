import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SocialSoundApp: App {

    @StateObject private var spotifyAuth = SpotifyAuthManager.shared
    @StateObject private var broadcast = BroadcastManager()
    @StateObject private var locationService = LocationService()
    @StateObject private var currentUserStore = CurrentUserStore()

    init() {
        FirebaseApp.configure()
        print("🔥 Firebase configured")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    FirebaseAuthBootstrap.ensureFirebaseUser()
                    currentUserStore.startListening()
                }
                .environmentObject(spotifyAuth)
                .environmentObject(broadcast)
                .environmentObject(locationService)
                .environmentObject(currentUserStore)
        }
    }
}
