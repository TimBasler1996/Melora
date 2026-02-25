import Foundation
import FirebaseAuth
import FirebaseFirestore

struct FollowerEntry: Identifiable {
    let id: String          // follow document ID
    let userId: String      // the follower's uid
    var displayName: String?
    var avatarURL: String?
    let followedAt: Date
}

@MainActor
final class FollowersInboxViewModel: ObservableObject {

    @Published var followers: [FollowerEntry] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        stopListening()
        isLoading = true
        errorMessage = nil

        guard let myUid = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "Not authenticated."
            return
        }

        let ref = db.collection("follows")
            .whereField("followingId", isEqualTo: myUid)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)

        listener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }

            if let error {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                return
            }

            let docs = snap?.documents ?? []

            let entries: [FollowerEntry] = docs.compactMap { doc in
                let data = doc.data()
                guard let followerId = data["followerId"] as? String else { return nil }
                let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                return FollowerEntry(
                    id: doc.documentID,
                    userId: followerId,
                    displayName: nil,
                    avatarURL: nil,
                    followedAt: createdAt
                )
            }

            self.followers = entries
            self.isLoading = false
            self.enrichWithUserData()
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    private func enrichWithUserData() {
        for index in followers.indices {
            if followers[index].displayName != nil { continue }

            let uid = followers[index].userId
            UserApiService.shared.getUser(uid: uid) { [weak self] result in
                guard let self else { return }

                switch result {
                case .success(let user):
                    DispatchQueue.main.async {
                        guard index < self.followers.count,
                              self.followers[index].userId == uid else { return }
                        self.followers[index].displayName = user.displayName
                        self.followers[index].avatarURL = (user.photoURLs?.first) ?? user.avatarURL
                    }
                case .failure(let error):
                    print("⚠️ [Followers] failed to fetch user \(uid):", error.localizedDescription)
                }
            }
        }
    }
}
