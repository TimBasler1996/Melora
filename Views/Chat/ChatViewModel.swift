import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    /// Transient error from an action (send/accept/decline). Shown as an alert
    /// instead of replacing the chat like `errorMessage` does.
    @Published var actionError: String?

    @Published var draft: String = ""
    @Published var isSending: Bool = false

    @Published var conversation: Conversation?
    @Published var isResponding: Bool = false

    /// The other participant's profile, loaded off the conversation's participant
    /// ids. Drives the chat thread header (avatar, name, live / last-seen status).
    @Published var peer: AppUser?

    /// Message the user is composing a reply to. When set, the composer shows
    /// a quote bar and the next sent message carries the reply context.
    @Published var replyingTo: ChatMessage?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?
    private var peerListener: ListenerRegistration?

    deinit {
        listener?.remove()
        conversationListener?.remove()
        peerListener?.remove()
    }

    /// When the *other* user last opened this conversation. Used to render
    /// a "Seen" label under the most recent message we sent.
    var otherUserLastReadAt: Date? {
        guard let convo = conversation else { return nil }
        guard let myId = Auth.auth().currentUser?.uid else { return nil }
        guard let otherId = convo.participantIds.first(where: { $0 != myId }) else { return nil }
        return convo.lastReadAt?[otherId]
    }

    var currentUserId: String? {
        Auth.auth().currentUser?.uid
    }

    /// True when the conversation is a pending message request and the current
    /// user is the recipient (i.e. they need to Accept or Decline).
    var needsAcceptance: Bool {
        guard let convo = conversation, convo.effectiveStatus == .pending else { return false }
        guard let myId = Auth.auth().currentUser?.uid else { return false }
        return convo.initiatorId != myId
    }

    /// True when the current user is the sender of a pending request that
    /// the other side hasn't accepted yet.
    var waitingForAcceptance: Bool {
        guard let convo = conversation, convo.effectiveStatus == .pending else { return false }
        guard let myId = Auth.auth().currentUser?.uid else { return false }
        return convo.initiatorId == myId
    }

    func start(conversationId: String) {
        stop()

        isLoading = true
        errorMessage = nil
        messages = []
        conversation = nil

        // Live-listen to the conversation doc so status changes (accept) update the UI.
        conversationListener = db.collection("conversations").document(conversationId)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    print("❌ [Chat] convo listen failed:", err.localizedDescription)
                    return
                }
                guard let snap, snap.exists, let data = snap.data() else {
                    self.isLoading = false
                    self.errorMessage = "Conversation not found."
                    return
                }
                let convo = Conversation.fromFirestore(id: conversationId, data: data)
                self.conversation = convo
                if let convo { self.startPeerListenerIfNeeded(participantIds: convo.participantIds) }
            }

        // Listen to messages
        let ref = self.db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)

        self.listener = ref.addSnapshotListener { [weak self] snap, err in
            guard let self else { return }

            if let err {
                self.isLoading = false
                self.errorMessage = err.localizedDescription
                print("❌ [Chat] listen failed:", err.localizedDescription)
                return
            }

            let docs = snap?.documents ?? []
            self.messages = docs.compactMap { ChatMessage.fromFirestore(id: $0.documentID, data: $0.data()) }
            self.isLoading = false
        }

        Task {
            await markAsRead(conversationId: conversationId)
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
        conversationListener?.remove()
        conversationListener = nil
        peerListener?.remove()
        peerListener = nil
    }

    /// Live-listen to the other participant's user doc so the header can show
    /// their avatar, name and up-to-date broadcasting / last-seen status.
    private func startPeerListenerIfNeeded(participantIds: [String]) {
        guard peerListener == nil else { return }
        guard let myId = Auth.auth().currentUser?.uid,
              let otherId = participantIds.first(where: { $0 != myId }) else { return }

        peerListener = db.collection("users").document(otherId)
            .addSnapshotListener { [weak self] snap, err in
                guard let self else { return }
                if let err {
                    print("❌ [Chat] peer listen failed:", err.localizedDescription)
                    return
                }
                guard let data = snap?.data() else { return }
                self.peer = AppUser.fromFirestore(uid: otherId, data: data)
            }
    }

    func markAsRead(conversationId: String) async {
        guard let myId = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("conversations").document(conversationId).updateData([
                "lastReadAt.\(myId)": Timestamp(date: Date())
            ])
        } catch {
            print("❌ [Chat] markAsRead failed:", error.localizedDescription)
        }
    }

    func send(conversationId: String) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let myId = Auth.auth().currentUser?.uid else { return }

        // Block sending in pending conversations.
        if let convo = conversation, convo.effectiveStatus == .pending {
            actionError = "Wait for the other user to accept your request before sending more messages."
            return
        }

        isSending = true
        defer { isSending = false }

        let replyContext = replyingTo
        replyingTo = nil

        do {
            let now = Date()

            let convoRef = db.collection("conversations").document(conversationId)
            let msgRef = convoRef.collection("messages").document()

            var payload: [String: Any] = [
                "senderId": myId,
                "text": text,
                "createdAt": now,
                "type": ChatMessage.MessageType.text.rawValue
            ]

            if let replyContext {
                payload["replyTo"] = [
                    "messageId": replyContext.id,
                    "senderId": replyContext.senderId,
                    "textPreview": String(replyContext.text.prefix(120))
                ]
            }

            try await msgRef.setData(payload)

            try await convoRef.setData([
                "lastMessageText": text,
                "lastMessageAt": now,
                "lastMessageSenderId": myId,
                "updatedAt": now
            ], merge: true)

            draft = ""
            print("✅ [Chat] sent message \(msgRef.documentID)")
        } catch {
            // Keep the draft and reply context so the user can retry.
            replyingTo = replyContext
            actionError = "Couldn’t send your message. Please try again."
            print("❌ [Chat] send failed:", error.localizedDescription)
        }
    }

    // MARK: - Reactions

    /// Toggle a heart reaction on a message. If the user already reacted
    /// with the same emoji, removes it; otherwise overwrites their previous one.
    func toggleReaction(_ emoji: String, on message: ChatMessage, conversationId: String) async {
        guard let myId = Auth.auth().currentUser?.uid else { return }

        let msgRef = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .document(message.id)

        let existing = message.reactions?[myId]
        let removing = existing == emoji

        do {
            if removing {
                try await msgRef.updateData([
                    "reactions.\(myId)": FieldValue.delete()
                ])
            } else {
                try await msgRef.updateData([
                    "reactions.\(myId)": emoji
                ])
            }
        } catch {
            print("❌ [Chat] reaction failed:", error.localizedDescription)
        }
    }

    func startReply(to message: ChatMessage) {
        replyingTo = message
    }

    func cancelReply() {
        replyingTo = nil
    }

    /// Accept a pending message request: mark the underlying like as accepted
    /// and the conversation as accepted.
    func acceptRequest() async {
        guard let convo = conversation, convo.effectiveStatus == .pending else { return }
        guard let myId = Auth.auth().currentUser?.uid, convo.initiatorId != myId else { return }

        isResponding = true
        defer { isResponding = false }

        do {
            if let likeId = convo.createdFromLikeId {
                try? await LikeApiService.shared.setLikeStatusReceivedOnly(
                    likeId: likeId,
                    toUserId: myId,
                    status: .accepted
                )
            }
            try await ChatApiService.shared.acceptConversation(conversationId: convo.id)
            // Optimistic update; the snapshot listener will confirm shortly.
            conversation?.status = .accepted
        } catch {
            actionError = "Couldn’t accept the request. Please try again."
            print("❌ [Chat] accept failed:", error.localizedDescription)
        }
    }

    /// Decline a pending message request: mark the underlying like and the
    /// conversation as rejected so the request disappears from the inbox.
    func declineRequest() async {
        guard let convo = conversation, convo.effectiveStatus == .pending else { return }
        guard let myId = Auth.auth().currentUser?.uid, convo.initiatorId != myId else { return }

        isResponding = true
        defer { isResponding = false }

        if let likeId = convo.createdFromLikeId {
            try? await LikeApiService.shared.setLikeStatusReceivedOnly(
                likeId: likeId,
                toUserId: myId,
                status: .rejected
            )
        }

        do {
            try await ChatApiService.shared.rejectConversation(conversationId: convo.id)
        } catch {
            actionError = "Couldn’t decline the request. Please try again."
            print("❌ [Chat] decline failed:", error.localizedDescription)
        }
    }
}
