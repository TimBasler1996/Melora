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
    private var likesListener: ListenerRegistration?
    private var followersListener: ListenerRegistration?

    deinit {
        likesListener?.remove()
        followersListener?.remove()
        if let seenObserver { NotificationCenter.default.removeObserver(seenObserver) }
    }

    private let lastSeenKey = "LikesInboxView_lastSeenDate"
    // Must match `FollowersInboxViewModel.lastSeenKey`, or the badge never clears.
    private let lastSeenFollowersKey = "FollowersInbox_lastSeenDate"

    private var lastSeenDate: Date? {
        UserDefaults.standard.object(forKey: lastSeenKey) as? Date
    }

    private var lastSeenFollowersDate: Date? {
        UserDefaults.standard.object(forKey: lastSeenFollowersKey) as? Date
    }

    private var unreadLikes: Int = 0
    private var unreadFollowers: Int = 0
    private var likeDates: [Date] = []
    private var followDates: [Date] = []
    private var seenObserver: NSObjectProtocol?

    // MARK: - Public

    func startListening(userId: String) {
        stopListening()
        isListening = true

        // Likes listener
        let likesRef = db.collection("users")
            .document(userId)
            .collection("likesReceived")
            .order(by: "createdAt", descending: true)
            .limit(to: 100)

        likesListener = likesRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                print("❌ LikesBadgeViewModel likes listener error:", error.localizedDescription)
                self.likeDates = []
                self.recount()
                return
            }

            guard let docs = snapshot?.documents else {
                self.likeDates = []
                self.recount()
                return
            }

            self.likeDates = docs.compactMap { doc -> Date? in
                let data = doc.data()
                // Likes with a message belong in the Chat tab; exclude them
                // so the Likes badge only reflects pure likes.
                let message = (data["message"] as? String)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard message.isEmpty else { return nil }
                if let ts = data["createdAt"] as? Timestamp { return ts.dateValue() }
                if let date = data["createdAt"] as? Date { return date }
                return nil
            }
            self.recount()
        }

        // Followers listener
        let followsRef = db.collection("follows")
            .whereField("followingId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)

        followersListener = followsRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self else { return }

            if let error {
                print("❌ LikesBadgeViewModel followers listener error:", error.localizedDescription)
                self.followDates = []
                self.recount()
                return
            }

            guard let docs = snapshot?.documents else {
                self.followDates = []
                self.recount()
                return
            }

            self.followDates = docs.compactMap { doc -> Date? in
                let data = doc.data()
                if let ts = data["createdAt"] as? Timestamp { return ts.dateValue() }
                if let date = data["createdAt"] as? Date { return date }
                return nil
            }
            self.recount()
        }

        // The Activity feed marks things seen; recount without a new snapshot.
        seenObserver = NotificationCenter.default.addObserver(
            forName: .activitySeen, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.recount() }
        }
    }

    /// Unseen = newer than the stored "last seen" dates.
    private func recount() {
        let likesSeen = lastSeenDate
        let followersSeen = lastSeenFollowersDate
        unreadLikes = likeDates.filter { date in
            guard let likesSeen else { return true }
            return date > likesSeen
        }.count
        unreadFollowers = followDates.filter { date in
            guard let followersSeen else { return true }
            return date > followersSeen
        }.count
        updateCombinedCount()
    }

    func stopListening() {
        likesListener?.remove()
        likesListener = nil
        followersListener?.remove()
        followersListener = nil
        if let seenObserver { NotificationCenter.default.removeObserver(seenObserver) }
        seenObserver = nil
        isListening = false
    }

    func markAllAsSeenNow() {
        let now = Date()
        UserDefaults.standard.set(now, forKey: lastSeenKey)
        UserDefaults.standard.set(now, forKey: lastSeenFollowersKey)
        unreadLikes = 0
        unreadFollowers = 0
        unreadCount = 0
    }

    private func updateCombinedCount() {
        unreadCount = unreadLikes + unreadFollowers
    }
}
