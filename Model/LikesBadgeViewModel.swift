//
//  LikesBadgeViewModel.swift
//  SocialSound
//
//  Created by Tim Basler on 05.01.2026.
//


import Foundation
import FirebaseFirestore

@MainActor
final class LikesBadgeViewModel: ObservableObject {

    @Published var unreadCount: Int = 0
    @Published var isListening: Bool = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    private let lastSeenKey = "LikesInboxView_lastSeenDate"

    private var lastSeenDate: Date? {
        UserDefaults.standard.object(forKey: lastSeenKey) as? Date
    }

    // MARK: - Public

    func startListening(userId: String) {
        stopListening()

        isListening = true

        let ref = db.collection("users")
            .document(userId)
            .collection("likesReceived")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)

        listener = ref.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                print("❌ LikesBadgeViewModel listener error:", error.localizedDescription)
                self.unreadCount = 0
                return
            }

            guard let docs = snapshot?.documents else {
                self.unreadCount = 0
                return
            }

            let seen = self.lastSeenDate

            // Unread = likes newer than lastSeenDate
            let unread = docs.compactMap { doc -> Date? in
                let data = doc.data()
                if let ts = data["createdAt"] as? Timestamp {
                    return ts.dateValue()
                }
                if let date = data["createdAt"] as? Date {
                    return date
                }
                return nil
            }
            .filter { likeDate in
                guard let seen else { return true }  // if never opened inbox -> all unread
                return likeDate > seen
            }
            .count

            self.unreadCount = unread
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        isListening = false
    }

    /// Call this when user leaves the inbox (or explicitly marks as read).
    func markAllAsSeenNow() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: lastSeenKey)
        unreadCount = 0
    }
}
