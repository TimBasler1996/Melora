import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ChatBadgeViewModel: ObservableObject {

    @Published var unreadCount: Int = 0

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func startListening() {
        stopListening()

        guard let myUid = Auth.auth().currentUser?.uid else { return }

        let ref = db.collection("conversations")
            .whereField("participantIds", arrayContains: myUid)

        listener = ref.addSnapshotListener { [weak self] snap, error in
            guard let self else { return }

            if let error {
                print("❌ [ChatBadge] listener error:", error.localizedDescription)
                self.unreadCount = 0
                return
            }

            let docs = snap?.documents ?? []
            var count = 0

            for doc in docs {
                let data = doc.data()
                let lastSender = data["lastMessageSenderId"] as? String
                guard lastSender != myUid else { continue }

                guard let lastAt = (data["lastMessageAt"] as? Timestamp)?.dateValue() else { continue }

                let lastReadAtDict = data["lastReadAt"] as? [String: Any]
                let myLastRead: Date? = {
                    guard let raw = lastReadAtDict?[myUid] else { return nil }
                    if let ts = raw as? Timestamp { return ts.dateValue() }
                    if let d = raw as? Date { return d }
                    return nil
                }()

                if let readAt = myLastRead {
                    if lastAt > readAt { count += 1 }
                } else {
                    count += 1
                }
            }

            self.unreadCount = count
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}
