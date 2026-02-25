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

        let ref = db.collection("conversations")
            .whereField("participantIds", arrayContains: myUid)
            .order(by: "updatedAt", descending: true)
            .limit(to: 100)

        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                print("❌ [ChatBadge] listener error:", error.localizedDescription)
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
            let unread = docs.filter { doc in
                let data = doc.data()

                // Skip conversations where I sent the last message
                let lastSenderId = data["lastMessageSenderId"] as? String
                if lastSenderId == myUid { return false }

                // Get the lastMessageAt timestamp
                let lastAt: Date?
                if let ts = data["lastMessageAt"] as? Timestamp {
                    lastAt = ts.dateValue()
                } else {
                    lastAt = nil
                }

                guard let messageDate = lastAt else { return false }

                // If never opened chats tab -> all are unread
                guard let seen else { return true }
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
