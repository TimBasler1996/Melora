//
//  ChatInboxRow.swift
//  SocialSound
//
//  Created by Tim Basler on 07.01.2026.
//

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
    var isUnread: Bool = false
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
                let lastSender = data["lastMessageSenderId"] as? String

                let updatedAt =
                    (data["updatedAt"] as? Timestamp)?.dateValue()
                    ?? (data["createdAt"] as? Timestamp)?.dateValue()

                // Compute unread status
                let lastReadAtDict = data["lastReadAt"] as? [String: Any]
                let myLastRead: Date? = {
                    guard let raw = lastReadAtDict?[myUid] else { return nil }
                    if let ts = raw as? Timestamp { return ts.dateValue() }
                    if let d = raw as? Date { return d }
                    return nil
                }()

                let isUnread: Bool = {
                    guard lastSender != myUid else { return false }
                    guard let msgAt = lastAt else { return false }
                    guard let readAt = myLastRead else { return true }
                    return msgAt > readAt
                }()

                return ChatInboxRow(
                    id: doc.documentID,
                    conversationId: doc.documentID,
                    otherUserId: other,
                    displayName: nil,
                    avatarURL: nil,
                    lastMessageText: lastText,
                    lastMessageAt: lastAt,
                    updatedAt: updatedAt,
                    isUnread: isUnread
                )
            }

            self.rows = baseRows
            self.isLoading = false

            self.enrichRowsWithUsers()
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    /// One-shot reload (pull-to-refresh)
    func reloadOnce() {
        startListening()
    }

    private func enrichRowsWithUsers() {
        for index in rows.indices {
            if rows[index].displayName != nil { continue }

            let uid = rows[index].otherUserId
            guard uid != "unknown" else { continue }

            UserApiService.shared.getUser(uid: uid) { [weak self] result in
                guard let self else { return }

                switch result {
                case .success(let other):
                    DispatchQueue.main.async {
                        // Ensure row still exists and still refers to same user
                        guard index < self.rows.count,
                              self.rows[index].otherUserId == uid else { return }

                        self.rows[index].displayName = other.displayName
                        self.rows[index].avatarURL = (other.photoURLs?.first) ?? other.avatarURL
                    }

                case .failure(let error):
                    print("⚠️ [ChatInbox] failed to fetch user \(uid):", error.localizedDescription)
                }
            }
        }
    }
}

