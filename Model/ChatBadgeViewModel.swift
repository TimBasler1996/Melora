//
//  ChatBadgeViewModel.swift
//  SocialSound
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ChatBadgeViewModel: ObservableObject {

    @Published var unreadCount: Int = 0

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private let lastSeenKey = "ChatInbox_lastSeenDate"

    private var lastSeenDate: Date? {
        UserDefaults.standard.object(forKey: lastSeenKey) as? Date
    }

    // MARK: - Public

    func startListening() {
        stopListening()

        guard let myUid = Auth.auth().currentUser?.uid else { return }

        // If user has never opened the chats tab, initialize lastSeenDate
        // to now so existing conversations don't show as falsely unread.
        if lastSeenDate == nil {
            UserDefaults.standard.set(Date(), forKey: lastSeenKey)
        }

        let ref = db.collection("conversations")
            .whereField("participantIds", arrayContains: myUid)
            .order(by: "updatedAt", descending: true)
            .limit(to: 100)

        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                print("[ChatBadge] listener error: \(error.localizedDescription)")
                self.unreadCount = 0
                return
            }

            guard let docs = snapshot?.documents else {
                self.unreadCount = 0
                return
            }

            guard let myUid = Auth.auth().currentUser?.uid else {
                self.unreadCount = 0
                return
            }

            let seen = self.lastSeenDate

            // Unread = conversations with a lastMessageAt newer than lastSeenDate
            // AND where the last message was NOT sent by the current user
            // AND where there is actually a message (lastMessageText is not empty)
            let unread = docs.filter { doc in
                let data = doc.data()

                // Skip conversations where I sent the last message
                let lastSenderId = data["lastMessageSenderId"] as? String
                if lastSenderId == myUid { return false }

                // Skip conversations with no actual message text
                let lastText = data["lastMessageText"] as? String ?? ""
                if lastText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return false }

                // Get the lastMessageAt timestamp
                let lastAt: Date?
                if let ts = data["lastMessageAt"] as? Timestamp {
                    lastAt = ts.dateValue()
                } else {
                    lastAt = nil
                }

                guard let messageDate = lastAt else { return false }
                guard let seen else { return false }
                return messageDate > seen
            }
            .count

            self.unreadCount = unread
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    func markAllAsSeenNow() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: lastSeenKey)
        unreadCount = 0
    }

    /// Static helper so views without a reference to the instance can mark chats as seen.
    static func markChatsSeen() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: "ChatInbox_lastSeenDate")
    }
}
