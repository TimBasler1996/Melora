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
        let payload: [String: Any] = [
            "followerId": currentUid,
            "followingId": userId,
            "createdAt": Timestamp(date: Date())
        ]

        try await db.collection(collection).document(docId).setData(payload)
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

    /// Real-time listener for the current user's following list.
    func listenToFollowing(onChange: @escaping (Set<String>) -> Void) -> ListenerRegistration? {
        guard let currentUid = Auth.auth().currentUser?.uid else { return nil }

        return db.collection(collection)
            .whereField("followerId", isEqualTo: currentUid)
            .addSnapshotListener { snapshot, _ in
                let ids = (snapshot?.documents ?? []).compactMap { $0.data()["followingId"] as? String }
                onChange(Set(ids))
            }
    }
}
