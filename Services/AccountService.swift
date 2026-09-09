import Foundation
import AuthenticationServices
import CryptoKit
import Security
import FirebaseAuth
import FirebaseFirestore

/// Account durability for an app that starts everyone as an anonymous
/// Firebase user:
///
/// - **Link with Apple** attaches a Sign in with Apple credential to the
///   current anonymous uid, so the profile, chats and followers survive a
///   reinstall or a sign-out. If that Apple ID already owns another
///   SocialSound account, we sign into that one instead.
/// - **Delete profile** asks the backend to wipe everything and the auth
///   user; the `onUserWritten` Cloud Function performs the deletion.
@MainActor
final class AccountService: ObservableObject {

    static let shared = AccountService()

    enum AccountError: LocalizedError {
        case notSignedIn
        case missingAppleToken
        case cancelled

        var errorDescription: String? {
            switch self {
            case .notSignedIn: return "You’re not signed in."
            case .missingAppleToken: return "Apple didn’t return a sign-in token. Please try again."
            case .cancelled: return "Sign in was cancelled."
            }
        }
    }

    /// Outcome of linking: either the anonymous account was upgraded in place
    /// or the user switched to the account their Apple ID already owned.
    enum LinkOutcome {
        case linked
        case switchedToExistingAccount
    }

    @Published private(set) var isLinkedWithApple: Bool = false

    /// Kept from the last Apple sign-in so the token can be revoked when the
    /// account is deleted (App Review guideline 5.1.1(v)).
    private var lastAppleAuthorizationCode: String?

    private var currentNonce: String?
    private var authHandle: AuthStateDidChangeListenerHandle?

    private init() {
        refreshLinkState()
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, _ in
            Task { @MainActor [weak self] in self?.refreshLinkState() }
        }
    }

    // MARK: - State

    var isAnonymous: Bool {
        Auth.auth().currentUser?.isAnonymous ?? true
    }

    private func refreshLinkState() {
        let providers = Auth.auth().currentUser?.providerData.map(\.providerID) ?? []
        isLinkedWithApple = providers.contains("apple.com")
    }

    // MARK: - Sign in with Apple

    /// Configure the `SignInWithAppleButton` request. Must be called from the
    /// button's `onRequest` closure so the nonce matches the completion.
    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonce()
        currentNonce = nonce
        request.requestedScopes = [.fullName]
        request.nonce = Self.sha256(nonce)
    }

    /// Handle the `SignInWithAppleButton` result: link to the anonymous user,
    /// or sign into the existing account when the Apple ID is already taken.
    func completeAppleSignIn(
        _ result: Result<ASAuthorization, Error>,
        stopping broadcast: BroadcastManager
    ) async throws -> LinkOutcome {
        let authorization: ASAuthorization
        switch result {
        case .success(let value):
            authorization = value
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code == .canceled { throw AccountError.cancelled }
            throw error
        }

        guard
            let appleCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let tokenData = appleCredential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8),
            let nonce = currentNonce
        else {
            throw AccountError.missingAppleToken
        }
        currentNonce = nil
        if let codeData = appleCredential.authorizationCode {
            lastAppleAuthorizationCode = String(data: codeData, encoding: .utf8)
        }

        let credential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleCredential.fullName
        )

        guard let user = Auth.auth().currentUser else { throw AccountError.notSignedIn }

        do {
            _ = try await user.link(with: credential)
            refreshLinkState()
            return .linked
        } catch let error as NSError where error.code == AuthErrorCode.credentialAlreadyInUse.rawValue {
            // This Apple ID already has a SocialSound account: switch to it.
            // Firebase hands back an updated credential for exactly this case.
            let updated = (error.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential) ?? credential
            // Leaving the anonymous session: tear down what belongs to it
            // while we still have permission to write.
            await detachCurrentSession(stopping: broadcast)
            _ = try await Auth.auth().signIn(with: updated)
            refreshLinkState()
            return .switchedToExistingAccount
        }
    }

    /// Stops the broadcast, detaches the push token and disconnects Spotify
    /// for the account we are about to leave.
    private func detachCurrentSession(stopping broadcast: BroadcastManager) async {
        if broadcast.isBroadcasting {
            await broadcast.stopBroadcasting()
        }
        if let uid = Auth.auth().currentUser?.uid {
            try? await Firestore.firestore().collection("users").document(uid).updateData([
                "fcmToken": FieldValue.delete()
            ])
        }
        SpotifyAuthManager.shared.disconnect()
    }

    // MARK: - Sign out (only meaningful for linked accounts)

    /// Signs out and starts a fresh anonymous session. Safe for linked
    /// accounts: signing in with Apple again restores everything.
    func signOut(stopping broadcast: BroadcastManager) async {
        await FirebaseAuthBootstrap.signOut(stopping: broadcast)
    }

    // MARK: - Delete

    /// Marks the account for deletion. The `onUserWritten` Cloud Function
    /// removes the user document, photos, follows, likes, conversations and
    /// finally the auth user; the app immediately continues with a fresh
    /// anonymous session.
    func deleteProfile(stopping broadcast: BroadcastManager) async throws {
        guard let uid = Auth.auth().currentUser?.uid else { throw AccountError.notSignedIn }

        if broadcast.isBroadcasting {
            await broadcast.stopBroadcasting()
        }

        // Apple requires the Sign in with Apple token to be revoked on
        // account deletion. Best effort: only possible with a recent code.
        if isLinkedWithApple, let code = lastAppleAuthorizationCode {
            try? await Auth.auth().revokeToken(withAuthorizationCode: code)
        }

        try await Firestore.firestore().collection("users").document(uid).setData([
            "deletionRequestedAt": FieldValue.serverTimestamp(),
            "isBroadcasting": false,
            "fcmToken": FieldValue.delete()
        ], merge: true)

        SpotifyAuthManager.shared.disconnect()
        try? Auth.auth().signOut()
        FirebaseAuthBootstrap.ensureFirebaseUser()
    }

    // MARK: - Nonce helpers

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var random: UInt8 = 0
            let status = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if status != errSecSuccess { random = UInt8.random(in: 0...255) }
            if Int(random) < charset.count {
                result.append(charset[Int(random)])
                remaining -= 1
            }
        }
        return result
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
