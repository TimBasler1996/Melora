import SwiftUI
import FirebaseCore
import FirebaseAuth

@main
struct SocialSoundApp: App {

    @StateObject private var spotifyAuth = SpotifyAuthManager.shared
    @StateObject private var broadcast = BroadcastManager()
    @StateObject private var locationService = LocationService()

    init() {
        FirebaseApp.configure()
        print("🔥 Firebase configured")
    }

    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    FirebaseAuthBootstrap.ensureFirebaseUser()
                }
                .environmentObject(spotifyAuth)
                .environmentObject(broadcast)
                .environmentObject(locationService)
        }
    }
}

