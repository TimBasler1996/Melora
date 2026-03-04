import Foundation
import FirebaseAuth
import FirebaseFirestore

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

        let docId = "\(currentUid)_\(userId)"
        let payload: [String: Any] = [
            "blockerId": currentUid,
            "blockedUserId": userId,
            "createdAt": Timestamp(date: Date())
        ]

        try await db.collection(collection).document(docId).setData(payload)
        print("✅ [Block] blocked user \(userId)")
    }

    func unblockUser(userId: String) async throws {
        guard let currentUid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "Block", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let docId = "\(currentUid)_\(userId)"
        try await db.collection(collection).document(docId).delete()
        print("✅ [Block] unblocked user \(userId)")
    }

    // MARK: - Queries

    func isBlocked(userId: String) async throws -> Bool {
        guard let currentUid = Auth.auth().currentUser?.uid else { return false }
        let docId = "\(currentUid)_\(userId)"
        let doc = try await db.collection(collection).document(docId).getDocument()
        return doc.exists
    }

    func fetchBlockedIds() async throws -> Set<String> {
        guard let currentUid = Auth.auth().currentUser?.uid else { return [] }

        let snapshot = try await db.collection(collection)
            .whereField("blockerId", isEqualTo: currentUid)
            .getDocuments()

        let ids = snapshot.documents.compactMap { $0.data()["blockedUserId"] as? String }
        return Set(ids)
    }
}
