import Foundation
import AuthenticationServices
import CryptoKit
import Security
import UIKit

/// Handles Spotify OAuth + PKCE, token storage (Keychain) and refresh.
@MainActor
final class SpotifyAuthManager: NSObject, ObservableObject {

    static let shared = SpotifyAuthManager()

    // MARK: - Public state

    @Published var isAuthorized: Bool = false

    /// Why the last interactive login did not end with tokens. Cleared when a
    /// new login starts, so screens waiting on `isAuthorized` can stop
    /// waiting as soon as the user closes the sheet.
    @Published private(set) var lastLoginFailure: LoginFailure?

    enum LoginFailure: Equatable {
        case cancelled
        case failed
    }
    @Published private(set) var tokens: SpotifyTokens?

    // MARK: - Private

    /// Public client id (PKCE flow, no client secret involved).
    private let clientId = "cc898154515f4c0e91a1a8952fc4b717"
    private let redirectURI = "socialsound-login://callback"

    private let authorizeURL = URL(string: "https://accounts.spotify.com/authorize")!
    private let tokenURL = URL(string: "https://accounts.spotify.com/api/token")!

    private let scopes = [
        "user-read-email",
        "user-read-private",
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing",
        // Profile: top artists, top tracks, public playlists.
        "user-top-read",
        "playlist-read-private"
    ].joined(separator: " ")

    private var authSession: ASWebAuthenticationSession?
    private var currentCodeVerifier: String?

    /// Prevents concurrent refresh requests.
    private var refreshTask: Task<SpotifyTokens, Error>?

    // MARK: - Init

    private override init() {
        super.init()
        loadTokensFromStorage()
    }

    // MARK: - Public API

    /// Call this from views to make sure user is authorized. Launches the
    /// interactive login only when there is no usable refresh token.
    func ensureAuthorized() {
        lastLoginFailure = nil
        if let t = tokens, t.expiresAt > Date().addingTimeInterval(30) {
            isAuthorized = true
            return
        }

        if tokens?.refreshToken != nil {
            Task {
                do {
                    _ = try await getValidAccessToken()
                } catch {
                    // Only re-login when Spotify rejected the refresh token.
                    // A network blip keeps the stored tokens and retries later.
                    if tokens == nil {
                        startAuthFlow()
                    }
                }
            }
            return
        }

        startAuthFlow()
    }

    /// Like `ensureAuthorized()`, but never launches the interactive login
    /// flow. Use from screens that should reflect the connection state
    /// without surprising the user with a login sheet.
    func refreshAuthorizationSilently() {
        if let t = tokens, t.expiresAt > Date().addingTimeInterval(30) {
            isAuthorized = true
            return
        }

        guard tokens?.refreshToken != nil else {
            isAuthorized = false
            return
        }

        Task {
            _ = try? await getValidAccessToken()
        }
    }

    /// Forget the stored login and ask again (e.g. after new scopes).
    func reconnect() {
        disconnect()
        startAuthFlow()
    }

    func disconnect() {
        tokens = nil
        isAuthorized = false
        KeychainStore.remove(forKey: Self.keychainKey)
    }

    /// Returns a valid access token, refreshing it if needed (never concurrently).
    /// Throws `SpotifyAuthError.notAuthorized` when the user has to reconnect;
    /// transient failures rethrow the underlying error and keep the tokens.
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
            isAuthorized = true
            return updated.accessToken
        } catch SpotifyAuthError.refreshRejected {
            // Spotify explicitly invalidated the refresh token → reconnect.
            print("❌ [Auth] Refresh token rejected → user must reconnect Spotify")
            disconnect()
            throw SpotifyAuthError.notAuthorized
        } catch {
            // Offline / 5xx / decoding hiccup: keep everything, try again later.
            print("⚠️ [Auth] Refresh failed transiently: \(error)")
            throw error
        }
    }

    // MARK: - Auth Flow (Login)

    private func startAuthFlow() {
        lastLoginFailure = nil
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

        authSession = ASWebAuthenticationSession(
            url: url,
            callbackURLScheme: "socialsound-login"
        ) { [weak self] callbackURL, error in
            guard let self else { return }

            if let error {
                print("❌ [Auth] Auth cancelled or failed: \(error)")
                let cancelled = (error as? ASWebAuthenticationSessionError)?.code == .canceledLogin
                Task { @MainActor in
                    self.lastLoginFailure = cancelled ? .cancelled : .failed
                }
                return
            }

            guard
                let callbackURL,
                let comps = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
                let code = comps.queryItems?.first(where: { $0.name == "code" })?.value,
                let verifier = self.currentCodeVerifier
            else {
                print("❌ [Auth] Callback missing code")
                Task { @MainActor in self.lastLoginFailure = .failed }
                return
            }

            Task {
                do {
                    try await self.exchangeCodeForTokens(code: code, verifier: verifier)
                    self.isAuthorized = true
                } catch {
                    print("❌ [Auth] Failed to exchange code for tokens: \(error)")
                    self.lastLoginFailure = .failed
                }
            }
        }

        authSession?.presentationContextProvider = self
        authSession?.prefersEphemeralWebBrowserSession = false
        _ = authSession?.start()
    }

    // MARK: - Token requests

    private func exchangeCodeForTokens(code: String, verifier: String) async throws {
        let decoded = try await requestTokens(parameters: [
            "client_id": clientId,
            "grant_type": "authorization_code",
            "code": code,
            "redirect_uri": redirectURI,
            "code_verifier": verifier
        ])

        let newTokens = SpotifyTokens(
            accessToken: decoded.accessToken,
            refreshToken: decoded.refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expiresIn))
        )
        tokens = newTokens
        saveTokensToStorage(newTokens)
    }

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
        let decoded = try await requestTokens(parameters: [
            "client_id": clientId,
            "grant_type": "refresh_token",
            "refresh_token": refreshToken
        ])

        let newTokens = SpotifyTokens(
            accessToken: decoded.accessToken,
            // Spotify's PKCE flow may rotate the refresh token. Persist the new
            // one when present; reusing the old (now invalid) token would break
            // every future refresh.
            refreshToken: decoded.refreshToken ?? refreshToken,
            expiresAt: Date().addingTimeInterval(TimeInterval(decoded.expiresIn))
        )
        tokens = newTokens
        saveTokensToStorage(newTokens)
        return newTokens
    }

    /// POSTs a form-encoded token request and decodes the response.
    /// 400/401 mean the grant itself is invalid (`refreshRejected`); anything
    /// else is treated as transient.
    private func requestTokens(parameters: [String: String]) async throws -> SpotifyTokenResponse {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Self.formEncoded(parameters)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAuthError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ [Auth] Spotify token HTTP \(http.statusCode): \(body)")
            if http.statusCode == 400 || http.statusCode == 401 {
                throw SpotifyAuthError.refreshRejected
            }
            throw SpotifyAuthError.invalidResponse
        }

        return try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
    }

    private static func formEncoded(_ parameters: [String: String]) -> Data? {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return parameters
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
            .data(using: .utf8)
    }

    // MARK: - Storage (Keychain)

    private static let keychainKey = "spotify.tokens"

    private func loadTokensFromStorage() {
        if let data = KeychainStore.data(forKey: Self.keychainKey),
           let stored = try? JSONDecoder().decode(SpotifyTokens.self, from: data) {
            tokens = stored
        } else if let migrated = Self.migrateLegacyDefaults() {
            tokens = migrated
            saveTokensToStorage(migrated)
        }

        isAuthorized = (tokens?.expiresAt ?? .distantPast) > Date().addingTimeInterval(30)
    }

    private func saveTokensToStorage(_ tokens: SpotifyTokens) {
        guard let data = try? JSONEncoder().encode(tokens) else { return }
        KeychainStore.set(data, forKey: Self.keychainKey)
    }

    /// Earlier builds kept the tokens in UserDefaults. Move them over once and
    /// wipe the old copies.
    private static func migrateLegacyDefaults() -> SpotifyTokens? {
        let defaults = UserDefaults.standard
        defer {
            defaults.removeObject(forKey: "spotify_access")
            defaults.removeObject(forKey: "spotify_refresh")
            defaults.removeObject(forKey: "spotify_exp")
        }
        guard
            let access = defaults.string(forKey: "spotify_access"),
            let refresh = defaults.string(forKey: "spotify_refresh")
        else { return nil }
        let expiresAt = defaults.object(forKey: "spotify_exp") as? Date ?? .distantPast
        return SpotifyTokens(accessToken: access, refreshToken: refresh, expiresAt: expiresAt)
    }

    // MARK: - PKCE Helpers

    private static func generateCodeVerifier(length: Int = 64) -> String {
        precondition(length >= 43 && length <= 128)

        let charset = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var verifier = ""
        verifier.reserveCapacity(length)

        for _ in 0..<length {
            verifier.append(charset[Int.random(in: 0..<charset.count)])
        }
        return verifier
    }

    private static func codeChallenge(for verifier: String) -> String {
        let hashed = SHA256.hash(data: Data(verifier.utf8))
        return base64URLEncode(Data(hashed))
    }

    private static func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
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

struct SpotifyTokens: Codable {
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
    /// Spotify answered 400/401 to a refresh: the grant is gone for good.
    case refreshRejected
}

// MARK: - Keychain

/// Minimal generic-password Keychain wrapper for small secrets.
private enum KeychainStore {

    private static let service = "com.socialsound.spotify"

    static func data(forKey key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else { return nil }
        return item as? Data
    }

    static func set(_ data: Data, forKey key: String) {
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let status = SecItemUpdate(base as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let addQuery = base.merging(attributes) { _, new in new }
            _ = SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    static func remove(forKey key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        _ = SecItemDelete(query as CFDictionary)
    }
}
