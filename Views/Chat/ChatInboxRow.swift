import Foundation
import FirebaseAuth
import FirebaseFirestore

struct ChatInboxRow: Identifiable {
    let id: String              // conversationId
    let conversationId: String
    let otherUserId: String

    var displayName: String?
    var avatarURL: String?

    var lastMessageText: String?
    var lastMessageAt: Date?
    var updatedAt: Date?
}

@MainActor
final class ChatInboxViewModel: ObservableObject {

    @Published var rows: [ChatInboxRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        stopListening()
        errorMessage = nil
        isLoading = true

        guard let myUid = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "Not authenticated."
            return
        }

        let ref = db.collection("conversations")
            .whereField("participantIds", arrayContains: myUid)
            .order(by: "updatedAt", descending: true)

        listener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }

            if let err {
                self.isLoading = false
                self.errorMessage = err.localizedDescription
                print("❌ [ChatInbox] listen failed:", err.localizedDescription)
                return
            }

            let docs = snap?.documents ?? []
            let baseRows: [ChatInboxRow] = docs.compactMap { doc in
                let data = doc.data()

                let participants = data["participantIds"] as? [String] ?? []
                let other = participants.first(where: { $0 != myUid }) ?? "unknown"

                let lastText = data["lastMessageText"] as? String
                let lastAt = (data["lastMessageAt"] as? Timestamp)?.dateValue()
                let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue()

                return ChatInboxRow(
                    id: doc.documentID,
                    conversationId: doc.documentID,
                    otherUserId: other,
                    displayName: nil,
                    avatarURL: nil,
                    lastMessageText: lastText,
                    lastMessageAt: lastAt,
                    updatedAt: updatedAt
                )
            }

            self.rows = baseRows
            self.isLoading = false

            // Enrich each row with user profile (displayName + avatar)
            Task { await self.enrichRowsWithUsers() }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// One-shot reload (for pull-to-refresh)
    func reloadOnce() {
        startListening()
    }

    private func enrichRowsWithUsers() async {
        // Fetch user info for rows that miss it
        for i in rows.indices {
            if rows[i].displayName != nil { continue }
            let uid = rows[i].otherUserId
            guard uid != "unknown" else { continue }

            do {
                let other = try await UserApiService.shared.fetchUser(userId: uid)
                rows[i].displayName = other.displayName
                rows[i].avatarURL = (other.photoURLs?.first) ?? other.avatarURL
            } catch {
                // Don’t fail the whole inbox if one profile can't load
                print("⚠️ [ChatInbox] failed to fetch user \(uid):", error.localizedDescription)
            }
        }
    }
}
