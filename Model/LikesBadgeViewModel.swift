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

    private let lastSeenKey = "LikesInboxView_lastSeenDate"
    private let lastSeenFollowersKey = "FollowersInboxView_lastSeenDate"

    private var lastSeenDate: Date? {
        UserDefaults.standard.object(forKey: lastSeenKey) as? Date
    }

    private var lastSeenFollowersDate: Date? {
        UserDefaults.standard.object(forKey: lastSeenFollowersKey) as? Date
    }

    private var unreadLikes: Int = 0
    private var unreadFollowers: Int = 0

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
                self.unreadLikes = 0
                self.updateCombinedCount()
                return
            }

            guard let docs = snapshot?.documents else {
                self.unreadLikes = 0
                self.updateCombinedCount()
                return
            }

            let seen = self.lastSeenDate
            let unread = docs.compactMap { doc -> Date? in
                let data = doc.data()
                if let ts = data["createdAt"] as? Timestamp { return ts.dateValue() }
                if let date = data["createdAt"] as? Date { return date }
                return nil
            }
            .filter { likeDate in
                guard let seen else { return true }
                return likeDate > seen
            }
            .count

            self.unreadLikes = unread
            self.updateCombinedCount()
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
                self.unreadFollowers = 0
                self.updateCombinedCount()
                return
            }

            guard let docs = snapshot?.documents else {
                self.unreadFollowers = 0
                self.updateCombinedCount()
                return
            }

            let seen = self.lastSeenFollowersDate
            let unread = docs.compactMap { doc -> Date? in
                let data = doc.data()
                if let ts = data["createdAt"] as? Timestamp { return ts.dateValue() }
                if let date = data["createdAt"] as? Date { return date }
                return nil
            }
            .filter { followDate in
                guard let seen else { return true }
                return followDate > seen
            }
            .count

            self.unreadFollowers = unread
            self.updateCombinedCount()
        }
    }

    func stopListening() {
        likesListener?.remove()
        likesListener = nil
        followersListener?.remove()
        followersListener = nil
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
