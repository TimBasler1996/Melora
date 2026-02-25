import Foundation
import FirebaseAuth
import FirebaseFirestore

final class FollowApiService {

    static let shared = FollowApiService()
    private init() {}

    private let db = Firestore.firestore()
    private let collection = "follows"

    // MARK: - Follow / Unfollow

    func follow(userId: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Follow", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        guard currentUid != userId else { return }

        let docId = "\(currentUid)_\(userId)"
        let now = Date()
        let payload: [String: Any] = [
            "followerId": currentUid,
            "followingId": userId,
            "createdAt": Timestamp(date: now)
        ]

        try await db.collection(collection).document(docId).setData(payload)

        // Create follow notification for the target user
        let notifPayload: [String: Any] = [
            "type": "follow",
            "fromUserId": currentUid,
            "toUserId": userId,
            "createdAt": Timestamp(date: now)
        ]
        try? await db.collection("users").document(userId)
            .collection("notifications").addDocument(data: notifPayload)
    }

    func unfollow(userId: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Follow", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let docId = "\(currentUid)_\(userId)"
        try await db.collection(collection).document(docId).delete()
    }

    // MARK: - Queries

    /// Returns all user IDs that the current user follows.
    func fetchFollowingIds() async throws -> Set<String> {
        guard let currentUid = Auth.auth().currentUser?.uid else { return [] }

        let snapshot = try await db.collection(collection)
            .whereField("followerId", isEqualTo: currentUid)
            .getDocuments()

        let ids = snapshot.documents.compactMap { $0.data()["followingId"] as? String }
        return Set(ids)
    }

    /// Returns all user IDs that follow the given user.
    func fetchFollowerIds(of userId: String) async throws -> Set<String> {
        let snapshot = try await db.collection(collection)
            .whereField("followingId", isEqualTo: userId)
            .getDocuments()

        let ids = snapshot.documents.compactMap { $0.data()["followerId"] as? String }
        return Set(ids)
    }

    /// Check if current user follows a specific user.
    func isFollowing(userId: String) async throws -> Bool {
        guard let currentUid = Auth.auth().currentUser?.uid else { return false }
        let docId = "\(currentUid)_\(userId)"
        let doc = try await db.collection(collection).document(docId).getDocument()
        return doc.exists
    }

    // MARK: - Notifications

    /// Fetch follow notifications for a user (people who followed them).
    func fetchFollowNotifications(for userId: String) async throws -> [FollowNotification] {
        let snapshot = try await db.collection("users").document(userId)
            .collection("notifications")
            .whereField("type", isEqualTo: "follow")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> FollowNotification? in
            let data = doc.data()
            guard let fromUserId = data["fromUserId"] as? String,
                  let timestamp = data["createdAt"] as? Timestamp else { return nil }
            return FollowNotification(
                id: doc.documentID,
                fromUserId: fromUserId,
                createdAt: timestamp.dateValue(),
                fromUserDisplayName: nil,
                fromUserAvatarURL: nil
            )
        }
    }

    /// Enrich follow notifications with user display data.
    func enrichFollowNotifications(_ notifications: [FollowNotification]) async -> [FollowNotification] {
        var enriched = notifications
        for i in enriched.indices {
            let uid = enriched[i].fromUserId
            if let doc = try? await db.collection("users").document(uid).getDocument(),
               let data = doc.data() {
                enriched[i].fromUserDisplayName = data["firstName"] as? String ?? data["displayName"] as? String
                let photos = data["photoURLs"] as? [String]
                enriched[i].fromUserAvatarURL = data["avatarURL"] as? String ?? photos?.first
            }
        }
        return enriched
    }

    /// Real-time listener for the current user's following list.
    func listenToFollowing(onChange: @escaping @Sendable (Set<String>) -> Void) -> ListenerRegistration? {
        guard let currentUid = Auth.auth().currentUser?.uid else { return nil }

        return db.collection(collection)
            .whereField("followerId", isEqualTo: currentUid)
            .addSnapshotListener { snapshot, _ in
                let ids = (snapshot?.documents ?? []).compactMap { $0.data()["followingId"] as? String }
                onChange(Set(ids))
            }
    }
}
