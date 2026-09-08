import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Owns the Firebase session lifecycle: anonymous sign-in on first launch and
/// sign-out. Everything that reacts to the session (profile store, listeners)
/// observes `Auth.auth()` state instead of calling this directly.
@MainActor
enum FirebaseAuthBootstrap {

    /// In-flight anonymous sign-in. Two callers on first launch (app root and
    /// onboarding state) must not each create their own anonymous account.
    private static var signInTask: Task<Void, Never>?

    /// Makes sure a Firebase user exists, signing in anonymously if needed.
    /// Safe to call repeatedly; concurrent calls share one request.
    static func ensureFirebaseUser() {
        if let user = Auth.auth().currentUser {
            print("✅ Firebase user already signed in: \(user.uid)")
            return
        }
        guard signInTask == nil else { return }

        signInTask = Task {
            defer { signInTask = nil }
            do {
                let result = try await Auth.auth().signInAnonymously()
                print("✅ Firebase anonymous user signed in: \(result.user.uid)")
            } catch {
                print("❌ Firebase anonymous auth failed: \(error)")
            }
        }
    }

    /// Signs the current user out and immediately provisions a fresh anonymous
    /// session so the app never sits in a "no user" state.
    ///
    /// Before the session goes away everything bound to it is torn down while
    /// we still have permission to write: an active broadcast is stopped, the
    /// push token is detached from the old account and Spotify is disconnected.
    static func signOut(stopping broadcast: BroadcastManager) async {
        if broadcast.isBroadcasting {
            await broadcast.stopBroadcasting()
        }

        if let uid = Auth.auth().currentUser?.uid {
            try? await Firestore.firestore().collection("users").document(uid).updateData([
                "fcmToken": FieldValue.delete()
            ])
        }

        SpotifyAuthManager.shared.disconnect()

        do {
            try Auth.auth().signOut()
            print("👋 Firebase user signed out")
        } catch {
            print("❌ Firebase sign-out failed: \(error)")
        }
        ensureFirebaseUser()
    }
}
