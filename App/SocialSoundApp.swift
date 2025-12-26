import SwiftUI
import FirebaseAuth

@main
struct SocialSoundApp: App {

    @UIApplicationDelegateAdaptor(AppDelegate.self)
    var delegate

    @StateObject private var spotifyAuth = SpotifyAuthManager.shared
    @StateObject private var broadcast = BroadcastManager()
    @StateObject private var locationService = LocationService()
    @StateObject private var presence = BroadcastPresenceManager() // ✅ NEW

    var body: some Scene {
        WindowGroup {
            MainView()
                .onAppear {
                    FirebaseAuthBootstrap.ensureFirebaseUser()
                }
                .environmentObject(spotifyAuth)
                .environmentObject(broadcast)
                .environmentObject(locationService)
                .environmentObject(presence)
        }
    }
}

