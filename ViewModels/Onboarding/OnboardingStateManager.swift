import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class OnboardingStateManager: ObservableObject {

    @Published var isLoading: Bool = true
    @Published var needsOnboarding: Bool = true
    @Published var appUser: AppUser?
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var authHandle: AuthStateDidChangeListenerHandle?
    private var hasLoadedOnce = false

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
                    self.errorMessage = err.localizedDescription
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

    private func observeAuthState() {
        if Auth.auth().currentUser != nil {
            hasLoadedOnce = true
            reload()
            return
        }

        authHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            guard user != nil, !self.hasLoadedOnce else { return }
            self.hasLoadedOnce = true
            self.reload()
        }
    }

    private func isProfileComplete(data: [String: Any]) -> Bool {
        let trimmed: (String?) -> String? = { value in
            value?.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let profileCompleted = (data["profileCompleted"] as? Bool) == true
        let firstName = trimmed(data["firstName"] as? String)
        let lastName = trimmed(data["lastName"] as? String)
        let city = trimmed(data["city"] as? String)
        let gender = trimmed(data["gender"] as? String)
        let spotifyId = trimmed(data["spotifyId"] as? String)

        let birthdayTimestamp = data["birthday"] as? Timestamp
        let birthdayDate = data["birthday"] as? Date
        let hasBirthday = birthdayTimestamp != nil || birthdayDate != nil

        let photoURLs = data["photoURLs"] as? [String]
        let hasPhotos = (photoURLs?.count ?? 0 >= 2) && (photoURLs?.count ?? 0 <= 5) && (photoURLs?.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } == true)

        let hasBasics = (firstName?.isEmpty == false)
            && (lastName?.isEmpty == false)
            && (city?.isEmpty == false)
            && (gender?.isEmpty == false)
            && (spotifyId?.isEmpty == false)
            && hasBirthday
            && hasPhotos

        return profileCompleted && hasBasics
    }
}
