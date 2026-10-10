import Foundation
import FirebaseAuth
import FirebaseFirestore

/// Blocking is one-directional and private to the blocker: blocked users are
/// hidden from Discover, Chats and search on the blocker's device. Documents
/// live at `blocks/{blockerId_blockedUserId}`.
final class BlockService {

    static let shared = BlockService()
    private init() {}

    private let db = Firestore.firestore()
    private let collection = "blocks"

    // MARK: - Block / Unblock

    func blockUser(userId: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Block", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        guard currentUid != userId else { return }

        try await db.collection(collection).document("\(currentUid)_\(userId)").setData([
            "blockerId": currentUid,
            "blockedUserId": userId,
            "createdAt": FieldValue.serverTimestamp()
        ])
    }

    func unblockUser(userId: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Block", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        try await db.collection(collection).document("\(currentUid)_\(userId)").delete()
    }

    // MARK: - Queries

    func isBlocked(userId: String) async throws -> Bool {
        guard let currentUid = Auth.auth().currentUser?.uid else { return false }
        let doc = try await db.collection(collection).document("\(currentUid)_\(userId)").getDocument()
        return doc.exists
    }

    /// Ids of every user the current user has blocked.
    func fetchBlockedIds() async throws -> Set<String> {
        guard let currentUid = Auth.auth().currentUser?.uid else { return [] }

        let snapshot = try await db.collection(collection)
            .whereField("blockerId", isEqualTo: currentUid)
            .getDocuments()

        return Set(snapshot.documents.compactMap { $0.data()["blockedUserId"] as? String })
    }

    /// Live set of blocked ids so screens update as soon as a user is blocked.
    func listenToBlockedIds(onChange: @escaping @Sendable (Set<String>) -> Void) -> ListenerRegistration? {
        guard let currentUid = Auth.auth().currentUser?.uid else { return nil }

        return db.collection(collection)
            .whereField("blockerId", isEqualTo: currentUid)
            .addSnapshotListener { snapshot, _ in
                let ids = (snapshot?.documents ?? []).compactMap { $0.data()["blockedUserId"] as? String }
                onChange(Set(ids))
            }
    }
}

/// One wording for blocking, used by every surface that offers it.
///
/// Block is reversible (Settings → Blocked and hidden) but it deletes the
/// shared conversation for both people, and that is not reversible. Both
/// halves have to be in the sentence wherever the action is offered —
/// Discover used to show it under "Hidden songs and people can be restored
/// in Settings", which promised the opposite.
enum BlockCopy {
    static func title(_ name: String) -> String { "Block \(name)?" }
    static let button = "Block"
    static let message = "They won’t appear in Discover, chats or search, and your chat with them is deleted for both of you. You can unblock them in Settings."
    static func failure(_ name: String) -> String { "Couldn’t block \(name). Please try again." }
    static let errorTitle = "Couldn’t do that"
    /// When the name is unknown.
    static let fallbackName = "this person"
}
