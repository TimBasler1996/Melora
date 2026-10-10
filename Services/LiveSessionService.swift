import FirebaseAuth
import Foundation

/// Asks the server to keep a live session visible while the app is closed.
///
/// Melora cannot refresh a broadcast from the background — iOS has no mode
/// that fits (the app plays no continuous audio, and location updates stop
/// when the user sits still). So the server does it: while a session the
/// user started is running, a scheduled job checks what they are playing.
///
/// Deliberately session-scoped, not always-on:
/// - the refresh token leaves the device only when "Go live" is tapped,
/// - the session has a hard two-hour ceiling,
/// - stopping deletes the token on the server rather than flagging it.
///
/// That matches Spotify's requirement to process data "only for as long as
/// is necessary to provide your SDA to the applicable user" and to delete it
/// on disconnect — and it is the version a user can actually consent to.
enum LiveSessionService {

    /// Whether the user has agreed to the server holding their session.
    /// Asked once, revocable in Settings.
    private static let consentKey = "liveSession.serverHoldConsent"

    private static let askedKey = "liveSession.serverHoldAsked"

    static var hasConsent: Bool {
        get { UserDefaults.standard.bool(forKey: consentKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: consentKey)
            UserDefaults.standard.set(true, forKey: askedKey)
        }
    }

    /// Whether the question has been put at all. Declining is an answer, so
    /// it must not re-ask on the next tap.
    static var hasBeenAsked: Bool { UserDefaults.standard.bool(forKey: askedKey) }

    private static let base = "https://us-central1-socialsound-5fdd9.cloudfunctions.net"

    enum LiveSessionError: Error { case notSignedIn, noRefreshToken, server }

    /// Hands the session to the server. Returns when it ends at the latest.
    @discardableResult
    static func start(refreshToken: String, location: LocationPoint?) async throws -> Date {
        let body: [String: Any] = {
            var payload: [String: Any] = ["refreshToken": refreshToken]
            if let location {
                payload["latitude"] = location.latitude
                payload["longitude"] = location.longitude
            }
            return payload
        }()

        let json = try await post("startLiveSession", body: body)
        guard let millis = json["expiresAt"] as? Double else { throw LiveSessionError.server }
        return Date(timeIntervalSince1970: millis / 1000)
    }

    /// Ends the hold and deletes the stored token.
    static func end() async {
        _ = try? await post("endLiveSession", body: [:])
    }

    private static func post(_ name: String, body: [String: Any]) async throws -> [String: Any] {
        guard let user = Auth.auth().currentUser else { throw LiveSessionError.notSignedIn }
        let idToken = try await user.getIDToken()

        var request = URLRequest(url: URL(string: "\(base)/\(name)")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw LiveSessionError.server
        }
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }
}
