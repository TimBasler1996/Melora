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

    var status: Conversation.Status = .accepted
    var initiatorId: String?
}

@MainActor
final class ChatInboxViewModel: ObservableObject {

    @Published var rows: [ChatInboxRow] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Accepted conversations only.
    var acceptedRows: [ChatInboxRow] {
        rows.filter { $0.status == .accepted }
    }

    /// Pending conversations where the *current user* is the recipient
    /// (i.e. someone sent them a message request).
    var pendingRequestRows: [ChatInboxRow] {
        guard let myUid = Auth.auth().currentUser?.uid else { return [] }
        return rows.filter { row in
            row.status == .pending && row.initiatorId != myUid
        }
    }

    /// Pending conversations where the *current user* sent the request
    /// (waiting for the other side to accept). Shown so the sender can still
    /// find the chat they just started from Discover.
    var sentRequestRows: [ChatInboxRow] {
        guard let myUid = Auth.auth().currentUser?.uid else { return [] }
        return rows.filter { row in
            row.status == .pending && row.initiatorId == myUid
        }
    }

    var todayRows: [ChatInboxRow] {
        acceptedRows.filter { row in
            guard let date = row.lastMessageAt ?? row.updatedAt else { return false }
            return Calendar.current.isDateInToday(date)
        }
    }

    var earlierRows: [ChatInboxRow] {
        acceptedRows.filter { row in
            guard let date = row.lastMessageAt ?? row.updatedAt else { return true }
            return !Calendar.current.isDateInToday(date)
        }
    }

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var blockListener: ListenerRegistration?

    /// Users the current user blocked; their chats are hidden.
    private var blockedIds: Set<String> = []
    private var allRows: [ChatInboxRow] = []

    deinit {
        listener?.remove()
        blockListener?.remove()
    }

    func startListening() {
        stopListening()
        errorMessage = nil
        isLoading = true

        guard let myUid = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "Not authenticated."
            return
        }

        blockListener = BlockService.shared.listenToBlockedIds { [weak self] ids in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.blockedIds = ids
                self.applyVisibleRows()
            }
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

                let status = (data["status"] as? String)
                    .flatMap(Conversation.Status.init(rawValue:))
                    ?? .accepted
                let initiatorId = data["initiatorId"] as? String

                return ChatInboxRow(
                    id: doc.documentID,
                    conversationId: doc.documentID,
                    otherUserId: other,
                    displayName: nil,
                    avatarURL: nil,
                    lastMessageText: lastText,
                    lastMessageAt: lastAt,
                    updatedAt: updatedAt,
                    isUnread: isUnread,
                    status: status,
                    initiatorId: initiatorId
                )
            }

            self.allRows = baseRows
            self.applyVisibleRows()
            self.isLoading = false

            self.enrichRowsWithUsers()
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        blockListener?.remove()
        blockListener = nil
    }

    /// One-shot reload (pull-to-refresh)
    func reloadOnce() {
        startListening()
    }

    /// Deletes a chat. The row disappears immediately and comes back with an
    /// error message if the delete failed.
    func deleteChat(_ row: ChatInboxRow) {
        let previousRows = allRows
        allRows.removeAll { $0.id == row.id }
        applyVisibleRows()
        Task {
            do {
                try await ChatApiService.shared.deleteConversation(conversationId: row.conversationId)
            } catch {
                allRows = previousRows
                applyVisibleRows()
                errorMessage = "Couldn’t delete the chat. Please try again."
                print("❌ [ChatInbox] delete failed:", error.localizedDescription)
            }
        }
    }

    private func applyVisibleRows() {
        rows = allRows.filter { !blockedIds.contains($0.otherUserId) }
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
                        // Rows may have been filtered/reordered meanwhile: match by user, not index.
                        let avatar = (other.photoURLs?.first) ?? other.avatarURL
                        for i in self.allRows.indices where self.allRows[i].otherUserId == uid {
                            self.allRows[i].displayName = other.displayName
                            self.allRows[i].avatarURL = avatar
                        }
                        for i in self.rows.indices where self.rows[i].otherUserId == uid {
                            self.rows[i].displayName = other.displayName
                            self.rows[i].avatarURL = avatar
                        }
                    }

                case .failure(let error):
                    print("⚠️ [ChatInbox] failed to fetch user \(uid):", error.localizedDescription)
                }
            }
        }
    }
}

