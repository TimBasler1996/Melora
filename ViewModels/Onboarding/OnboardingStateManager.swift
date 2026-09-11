import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Decides whether the signed-in user still needs onboarding and exposes the
/// current auth uid so user-scoped services can be (re)started when the
/// session changes (first launch, sign-out).
@MainActor
final class OnboardingStateManager: ObservableObject {

    @Published var isLoading: Bool = true
    @Published var needsOnboarding: Bool = true
    @Published var appUser: AppUser?
    @Published var errorMessage: String?

    /// Uid of the current Firebase user, `nil` while signed out / signing in.
    @Published private(set) var authUid: String?

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?

    init() {
        FirebaseAuthBootstrap.ensureFirebaseUser()
        observeAuthState()
    }

    deinit {
        if let authHandle {
            Auth.auth().removeStateDidChangeListener(authHandle)
        }
    }

    func reload() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "Not authenticated."
            isLoading = false
            needsOnboarding = true
            appUser = nil
            return
        }

        isLoading = true
        errorMessage = nil

        db.collection("users").document(uid).getDocument { [weak self] snap, err in
            guard let self else { return }

            if let err {
                Task { @MainActor in
                    self.errorMessage = UserFacingError.message(for: err, fallback: "Couldn’t load your profile. Check your connection and try again.")
                    self.isLoading = false
                    self.needsOnboarding = true
                }
                return
            }

            guard let snap, snap.exists, let data = snap.data() else {
                Task { @MainActor in
                    self.appUser = nil
                    self.needsOnboarding = true
                    self.isLoading = false
                }
                return
            }

            let appUser = AppUser.fromFirestore(uid: uid, data: data)
            let isComplete = self.isProfileComplete(data: data)

            Task { @MainActor in
                self.appUser = appUser
                self.needsOnboarding = !isComplete
                self.isLoading = false
            }
        }
    }

    // MARK: - Auth observation

    private func observeAuthState() {
        // The listener fires once immediately with the current state, then on
        // every change (anonymous sign-in completing, sign-out, re-sign-in).
        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            let uid = user?.uid
            Task { @MainActor [weak self] in
                self?.handleAuthChange(uid: uid)
            }
        }
    }

    private func handleAuthChange(uid: String?) {
        guard uid != authUid || appUser == nil else { return }
        authUid = uid

        guard uid != nil else {
            // Signed out: show the loading screen while a fresh anonymous
            // session is provisioned, then fall through to onboarding.
            appUser = nil
            needsOnboarding = true
            isLoading = true
            FirebaseAuthBootstrap.ensureFirebaseUser()
            return
        }

        reload()
    }

    // MARK: - Completeness

    nonisolated private func isProfileComplete(data: [String: Any]) -> Bool {
        let trimmed: (String?) -> String? = { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let profileCompleted = (data["profileCompleted"] as? Bool) == true
        let firstName = trimmed(data["firstName"] as? String)
        let lastName = trimmed(data["lastName"] as? String)
        let city = trimmed(data["city"] as? String)
        let gender = trimmed(data["gender"] as? String)

        let birthdayTimestamp = data["birthday"] as? Timestamp
        let birthdayDate = data["birthday"] as? Date
        let hasBirthday = birthdayTimestamp != nil || birthdayDate != nil

        // Count real photos only. Older clients stored padded slots ("") and
        // an upper bound here would lock users out of the app, so only the
        // minimum is enforced.
        let photoURLs = (data["photoURLs"] as? [String]) ?? []
        let realPhotoCount = photoURLs
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
        let hasPhotos = realPhotoCount >= ProfileViewModel.minPhotoCount

        // Spotify is optional ("Skip for now" in onboarding); it is deliberately
        // not part of the completeness check.
        let hasBasics = (firstName?.isEmpty == false)
            && (lastName?.isEmpty == false)
            && (city?.isEmpty == false)
            && (gender?.isEmpty == false)
            && hasBirthday
            && hasPhotos

        return profileCompleted && hasBasics
    }
}
