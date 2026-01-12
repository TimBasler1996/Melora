import Foundation
import AuthenticationServices
import CryptoKit
import UIKit

/// Handles Spotify OAuth + PKCE, token storage and refresh.
@MainActor
final class SpotifyAuthManager: NSObject, ObservableObject {

    static let shared = SpotifyAuthManager()

    // MARK: - Public state

    @Published var isAuthorized: Bool = false
    @Published private(set) var tokens: SpotifyTokens?

    // MARK: - Private

    private let clientId = "cc898154515f4c0e91a1a8952fc4b717"
    private let redirectURI = "socialsound-login://callback"

    private let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    private let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!

    private let scopes = [
        "user-read-email",
        "user-read-private",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing"
    ].joined(separator: " ")

    private var authSession: ASWebAuthenticationSession?
    private var currentCodeVerifier: String?

    private let defaults = UserDefaults.standard

    /// Prevents concurrent refresh requests.
    private var refreshTask: Task<SpotifyTokens, Error>?

    // MARK: - Init

    private override init() {
        super.init()
        loadTokensFromStorage()
    }

    // MARK: - Public API

    /// Call this from views to make sure user is authorized.
    func ensureAuthorized() {
        print("🔵 [Auth] ensureAuthorized() called")

        // Token still valid?
        if let t = tokens, t.expiresAt > Date().addingTimeInterval(30) {
            print("🟢 [Auth] Already authorized")
            isAuthorized = true
            return
        }

        // Try refresh if possible (single-flight)
        if tokens?.refreshToken != nil {
            print("🟡 [Auth] Trying refresh…")
            Task {
                do {
                    _ = try await getValidAccessToken()
                    print("🟢 [Auth] Refresh successful")
                    self.isAuthorized = true
                } catch {
                    print("❌ [Auth] Refresh failed → starting auth flow: \(error)")
                    self.startAuthFlow()
                }
            }
            return
        }

        // No token → Full Login Flow
        print("🟠 [Auth] No tokens → starting auth flow")
        startAuthFlow()
    }

    func disconnect() {
        print("🔴 [Auth] Disconnect from Spotify")
        tokens = nil
        isAuthorized = false

        defaults.removeObject(forKey: "spotify_access")
        defaults.removeObject(forKey: "spotify_refresh")
        defaults.removeObject(forKey: "spotify_exp")
    }

    /// Returns a valid access token.
    /// If expired, refresh will be performed, but never concurrently.
    func getValidAccessToken() async throws -> String {
        if let t = tokens, t.expiresAt > Date().addingTimeInterval(30) {
            return t.accessToken
        }

        guard let refresh = tokens?.refreshToken else {
            isAuthorized = false
            throw SpotifyAuthError.noRefreshToken
        }

        do {
            let updated = try await refreshAccessTokenSingleFlight(refreshToken: refresh)
            self.isAuthorized = true
            return updated.accessToken
        } catch {
            print("❌ [Auth] Refresh in getValidAccessToken() failed: \(error)")
            tokens = nil
            isAuthorized = false
            throw SpotifyAuthError.notAuthorized
        }
    }

    // MARK: - Auth Flow (Login)

    private func startAuthFlow() {
        print("🔵 [Auth] startAuthFlow()")

        let verifier = Self.generateCodeVerifier()
        let challenge = Self.codeChallenge(for: verifier)
        currentCodeVerifier = verifier

        var components = URLComponents(url: authorizeURL, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientId),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "scope", value: scopes),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "show_dialog", value: "true")
        ]

        guard let url = components.url else {
            print("❌ [Auth] Failed to build authorize URL")
            return
        }

        print("🔗 [Auth] Auth URL: \(url.absoluteString)")

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "socialsound-login"
        ) { [weak self] callbackURL, error in
            guard let self else { return }

            if let error = error {
                print("❌ [Auth] Auth cancelled or failed: \(error)")
                return
            }

            guard
                let callbackURL = callbackURL,
                let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                let codeItem = comps.queryItems?.first(where: { $0.name == "code" }),
                let code = codeItem.value,
                let verifier = self.currentCodeVerifier
            else {
                print("❌ [Auth] Callback missing code")
                return
            }

            print("🔵 [Auth] Got auth code → exchanging tokens…")
            Task {
                do {
                    try await self.exchangeCodeForTokens(code: code, verifier: verifier)
                    self.isAuthorized = true
                    print("🟢 [Auth] Authorization completed")
                } catch {
                    print("❌ [Auth] Failed to exchange code for tokens: \(error)")
                }
            }
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false

        let started = authSession?.start() ?? false
        print("🔵 [Auth] ASWebAuthenticationSession started = \(started)")
    }

    // MARK: - Token Exchange

    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier
        ]

        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ Spotify token HTTP \(http.statusCode): \(body)")
            throw SpotifyAuthError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expiresIn))

        let newTokens = SpotifyTokens(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: expiresAt
        )

        tokens = newTokens
        saveTokensToStorage(newTokens)
    }

    // MARK: - Refresh

    private func refreshAccessTokenSingleFlight(refreshToken: String) async throws -> SpotifyTokens {
        if let task = refreshTask {
            return try await task.value
        }

        let task = Task { try await refreshAccessToken(refreshToken: refreshToken) }
        refreshTask = task

        defer { refreshTask = nil }
        return try await task.value
    }

    private func refreshAccessToken(refreshToken: String) async throws -> SpotifyTokens {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = [
            "client_id": clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ]

        request.httpBody = body
            .map { "\($0.key)=\($0.value)" }
            .joined(separator: "&")
            .data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ Spotify refresh HTTP \(http.statusCode): \(body)")
            throw SpotifyAuthError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expiresIn))

        let newTokens = SpotifyTokens(
            accessToken: decoded.accessToken,
            refreshToken: refreshToken,
            expiresAt: expiresAt
        )

        tokens = newTokens
        saveTokensToStorage(newTokens)
        return newTokens
    }

    // MARK: - Storage

    private func loadTokensFromStorage() {
        guard
            let access = defaults.string(forKey: "spotify_access"),
            let refresh = defaults.string(forKey: "spotify_refresh")
        else {
            isAuthorized = false
            return
        }

        let expiresAt = defaults.object(forKey: "spotify_exp") as? Date ?? Date.distantPast

        tokens = SpotifyTokens(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: expiresAt
        )

        isAuthorized = expiresAt > Date().addingTimeInterval(30)
    }

    private func saveTokensToStorage(_ tokens: SpotifyTokens) {
        defaults.set(tokens.accessToken, forKey: "spotify_access")
        defaults.set(tokens.refreshToken, forKey: "spotify_refresh")
        defaults.set(tokens.expiresAt, forKey: "spotify_exp")
    }
}

// MARK: - ASWebAuthenticationPresentationContextProviding

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? ASPresentationAnchor()
    }
}

// MARK: - Token Models

struct SpotifyTokens {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

struct SpotifyTokenResponse: Codable {
    let accessToken: String
    let tokenType: String
    let expiresIn: Int
    let refreshToken: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
    }
}

// MARK: - Errors

enum SpotifyAuthError: Error {
    case invalidResponse
    case noRefreshToken
    case notAuthorized
}
