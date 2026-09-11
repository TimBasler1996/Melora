import Foundation
import FirebaseAuth

/// Copies the user's top artists, top tracks and playlists from Spotify to
/// their user document, at most once a day, so profiles can show them.
@MainActor
enum SpotifyTasteSync {

    private static let interval: TimeInterval = 24 * 60 * 60
    private static func key(_ uid: String) -> String { "spotifyTaste.lastSync.\(uid)" }

    /// Set when Spotify refused because the stored login predates the
    /// taste scopes; Settings offers a reconnect in that case.
    static var needsReconnect: Bool {
        get { UserDefaults.standard.bool(forKey: "spotifyTaste.needsReconnect") }
        set { UserDefaults.standard.set(newValue, forKey: "spotifyTaste.needsReconnect") }
    }

    static func syncIfNeeded(force: Bool = false) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        // A refresh token is enough; the access token is fetched on demand.
        guard force || SpotifyAuthManager.shared.tokens?.refreshToken != nil else { return }

        let last = UserDefaults.standard.object(forKey: key(uid)) as? Date
        if !force, let last, Date().timeIntervalSince(last) < interval { return }

        do {
            async let artists = SpotifyService.shared.fetchTopArtists(limit: 6)
            async let tracks = SpotifyService.shared.fetchTopTracks(limit: 5)
            async let playlists = SpotifyService.shared.fetchMyPlaylists(limit: 8)
            let taste = SpotifyTaste(topArtists: try await artists, topTracks: try await tracks, playlists: try await playlists)

            UserApiService.shared.updateProfile(uid: uid, updates: ["spotifyTaste": taste.firestoreValue])
            UserDefaults.standard.set(Date(), forKey: key(uid))
            needsReconnect = false
        } catch SpotifyAPIError.insufficientScope {
            // Logged in before we asked for the taste scopes.
            needsReconnect = true
        } catch {
            print("⚠️ [SpotifyTaste] sync failed: \(error)")
        }
    }
}
