import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class CurrentUserStore: ObservableObject {

    @Published var user: AppUser?
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    private lazy var db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit {
        // deinit is nonisolated → don't call MainActor methods here
        listener?.remove()
        listener = nil
    }

    func startListening() {
        stopListening()

        isLoading = true
        errorMessage = nil

        guard let uid = Auth.auth().currentUser?.uid else {
            user = nil
            isLoading = false
            errorMessage = "Not authenticated."
            return
        }

        listener = db.collection("users").document(uid).addSnapshotListener { [weak self] snap, err in
            guard let self else { return }

            if let err {
                self.errorMessage = err.localizedDescription
                self.isLoading = false
                return
            }

            guard let snap, snap.exists, let data = snap.data() else {
                self.user = nil
                self.isLoading = false
                self.errorMessage = "User document not found."
                return
            }

            let user = AppUser.fromFirestore(uid: uid, data: data)
            self.user = user
            self.isLoading = false
            if let user { SpotifyTasteSync.hidden = user.spotifyTasteHidden }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

