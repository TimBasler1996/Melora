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
    
    /// Scopes für Playback + aktueller Track
    private let scopes = [
        "user-read-playback-state",
        "user-modify-playback-state",
        "user-read-currently-playing"
    ].joined(separator: " ")
    
    private var authSession: ASWebAuthenticationSession?
    private var currentCodeVerifier: String?
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Init
    
    private override init() {
        super.init()
        loadTokensFromStorage()
    }
    
    // MARK: - Public API
    
    /// Sicherstellen, dass wir eingeloggt sind (wird z.B. aus Views aufgerufen).
    func ensureAuthorized() {
        print("🔵 [Auth] ensureAuthorized() called")
        
        // Token noch gültig?
        if let t = tokens, t.expiresAt > Date().addingTimeInterval(30) {
            print("🟢 [Auth] Already authorized")
            isAuthorized = true
            return
        }
        
        // Refresh möglich?
        if let refresh = tokens?.refreshToken {
            print("🟡 [Auth] Trying refresh…")
            Task {
                do {
                    try await self.refreshAccessToken(refreshToken: refresh)
                    print("🟢 [Auth] Refresh successful")
                    self.isAuthorized = true
                } catch {
                    print("❌ [Auth] Refresh failed → starting auth flow: \(error)")
                    self.startAuthFlow()
                }
            }
            return
        }
        
        // Kein Token → Full Login Flow
        print("🟠 [Auth] No tokens → starting auth flow")
        startAuthFlow()
    }
    
    /// Wird z.B. im Profil genutzt, um Spotify zu trennen.
    func disconnect() {
        print("🔴 [Auth] Disconnect from Spotify")
        tokens = nil
        isAuthorized = false
        
        defaults.removeObject(forKey: "spotify_access")
        defaults.removeObject(forKey: "spotify_refresh")
        defaults.removeObject(forKey: "spotify_exp")
    }
    
    /// Wird von SpotifyService / Playback genutzt, um ein garantiert gültiges Access Token zu bekommen.
    /// Falls nötig, wird intern ein Refresh gemacht. Wenn das nicht geht → Fehler.
    func getValidAccessToken() async throws -> String {
        // 1) Noch gültig?
        if let t = tokens, t.expiresAt > Date().addingTimeInterval(30) {
            return t.accessToken
        }
        
        // 2) Refresh versuchen
        if let refresh = tokens?.refreshToken {
            do {
                try await refreshAccessToken(refreshToken: refresh)
                if let t = tokens {
                    return t.accessToken
                }
            } catch {
                print("❌ [Auth] Refresh in getValidAccessToken() failed: \(error)")
                tokens = nil
                isAuthorized = false
                throw SpotifyAuthError.notAuthorized
            }
        }
        
        // 3) Nichts zu machen → nicht autorisiert
        isAuthorized = false
        throw SpotifyAuthError.notAuthorized
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
        
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            print("❌ [Auth] Token exchange failed: \(String(data: data, encoding: .utf8) ?? "")")
            throw SpotifyAuthError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(SpotifyTokenResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        
        let tokenModel = SpotifyTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token,
            expiresAt: expiresAt
        )
        
        saveTokens(tokenModel)
        print("💾 [Auth] Tokens stored (login)")
    }
    
    // MARK: - Token Refresh
    
    private func refreshAccessToken(refreshToken: String) async throws {
        print("🔵 [Auth] refreshing access token…")
        
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
        
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            print("❌ [Auth] Refresh failed: \(String(data: data, encoding: .utf8) ?? "")")
            throw SpotifyAuthError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(SpotifyRefreshResponse.self, from: data)
        let expiresAt = Date().addingTimeInterval(TimeInterval(decoded.expires_in))
        
        let updated = SpotifyTokens(
            accessToken: decoded.access_token,
            refreshToken: decoded.refresh_token ?? refreshToken,
            expiresAt: expiresAt
        )
        
        saveTokens(updated)
        print("💾 [Auth] Tokens stored (refresh)")
    }
    
    // MARK: - Token Storage
    
    private func saveTokens(_ tokens: SpotifyTokens) {
        self.tokens = tokens
        defaults.set(tokens.accessToken, forKey: "spotify_access")
        defaults.set(tokens.refreshToken, forKey: "spotify_refresh")
        defaults.set(tokens.expiresAt.timeIntervalSince1970, forKey: "spotify_exp")
    }
    
    private func loadTokensFromStorage() {
        guard let access = defaults.string(forKey: "spotify_access") else {
            isAuthorized = false
            return
        }
        let refresh = defaults.string(forKey: "spotify_refresh")
        let exp = defaults.double(forKey: "spotify_exp")
        
        let loaded = SpotifyTokens(
            accessToken: access,
            refreshToken: refresh,
            expiresAt: Date(timeIntervalSince1970: exp)
        )
        tokens = loaded
        isAuthorized = loaded.expiresAt > Date()
        
        print("💾 [Auth] Loaded tokens from storage, isAuthorized=\(isAuthorized)")
    }
    
    // MARK: - PKCE Helpers
    
    static func generateCodeVerifier() -> String {
        let chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~"
        return String((0..<64).map { _ in chars.randomElement()! })
    }
    
    static func codeChallenge(for verifier: String) -> String {
        let data = Data(verifier.utf8)
        return data.sha256Base64URL()
    }
}

// MARK: - Models

struct SpotifyTokens {
    let accessToken: String
    let refreshToken: String?
    let expiresAt: Date
}

struct SpotifyTokenResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

struct SpotifyRefreshResponse: Codable {
    let access_token: String
    let refresh_token: String?
    let expires_in: Int
}

enum SpotifyAuthError: Error {
    case notAuthorized
    case invalidResponse
    case noRefreshToken
}

// MARK: - ASWebAuthenticationSession presentation

extension SpotifyAuthManager: ASWebAuthenticationPresentationContextProviding {
    func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        // Use the key window if possible
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }
}

// MARK: - Crypto Helper

extension Data {
    func sha256Base64URL() -> String {
        let hash = SHA256.hash(data: self)
        return Data(hash).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
