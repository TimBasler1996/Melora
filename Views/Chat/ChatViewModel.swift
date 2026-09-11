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
    /// The conversation document is gone (deleted by either side).
    @Published var conversationMissing: Bool = false

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

    /// The other participant's uid, once the conversation has loaded.
    var otherUserId: String? {
        guard let convo = conversation, let myId = currentUserId else { return nil }
        return convo.participantIds.first { $0 != myId }
    }

    // MARK: - Delete / Block

    /// Deletes the conversation. Returns `true` on success so the view can pop.
    func deleteConversation(conversationId: String) async -> Bool {
        do {
            stop()
            try await ChatApiService.shared.deleteConversation(conversationId: conversationId)
            return true
        } catch {
            actionError = "Couldn’t delete the chat. Please try again."
            print("❌ [Chat] delete failed:", error.localizedDescription)
            return false
        }
    }

    /// Blocks the other participant and removes this chat. Returns `true` on success.
    func blockOtherUser(conversationId: String) async -> Bool {
        guard let otherId = otherUserId else { return false }
        do {
            try await BlockService.shared.blockUser(userId: otherId)
        } catch {
            actionError = "Couldn’t block this user. Please try again."
            print("❌ [Chat] block failed:", error.localizedDescription)
            return false
        }
        return await deleteConversation(conversationId: conversationId)
    }

    /// The request was declined. `declinedByMe` tells the two sides apart.
    var isDeclined: Bool {
        conversation?.effectiveStatus == .rejected
    }

    var declinedByMe: Bool {
        guard let convo = conversation, convo.effectiveStatus == .rejected,
              let myId = currentUserId else { return false }
        return convo.initiatorId != myId
    }

    /// True when the conversation is a pending message request and the current
    /// user is the recipient (i.e. they need to Accept or Decline).
    var needsAcceptance: Bool {
        guard let convo = conversation, convo.effectiveStatus == .pending else { return false }
        guard let myId = Auth.auth().currentUser?.uid else { return false }
        return convo.initiatorId != myId
    }

    /// A request I started that has no message yet (recreated after a
    /// delete): the composer stays open for exactly that first message.
    var canSendFirstRequestMessage: Bool {
        guard let convo = conversation, convo.effectiveStatus == .pending else { return false }
        return convo.initiatorId == currentUserId && messages.isEmpty
    }

    /// True when the current user is the sender of a pending request that
    /// the other side hasn't accepted yet.
    var waitingForAcceptance: Bool {
        guard let convo = conversation, convo.effectiveStatus == .pending else { return false }
        guard let myId = Auth.auth().currentUser?.uid else { return false }
        return convo.initiatorId == myId
    }

    func start(conversationId: String, peerUserId: String? = nil) {
        stop()

        // Opened from a profile: show who this is even before any
        // conversation document exists.
        if let peerUserId, let myId = currentUserId {
            startPeerListenerIfNeeded(participantIds: [myId, peerUserId])
        }

        isLoading = true
        errorMessage = nil
        conversationMissing = false
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
                    self.conversationMissing = true
                    self.errorMessage = "This chat no longer exists."
                    return
                }
                self.conversationMissing = false
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
                self.errorMessage = UserFacingError.message(for: err, fallback: "Check your connection and try again.")
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
            // Server time, like `lastMessageAt`, so unread / "Seen" comparisons
            // never mix two devices' clocks.
            try await db.collection("conversations").document(conversationId).updateData([
                "lastReadAt.\(myId)": FieldValue.serverTimestamp()
            ])
        } catch {
            print("❌ [Chat] markAsRead failed:", error.localizedDescription)
        }
    }

    func send(conversationId: String, peerUserId: String? = nil) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard Auth.auth().currentUser != nil else { return }

        // Opened from a profile with no conversation yet: the first message
        // creates the request, then flows through the normal path.
        if conversation == nil, conversationMissing, let peerUserId {
            isSending = true
            do {
                let convo = try await ChatApiService.shared.createRequestConversation(with: peerUserId)
                try await ChatApiService.shared.sendMessage(conversationId: convo.id, text: text, replyTo: nil)
                draft = ""
                isSending = false
                start(conversationId: convo.id)
            } catch {
                isSending = false
                actionError = UserFacingError.message(for: error, fallback: "Couldn’t send your message. Please try again.")
            }
            return
        }

        // A pending request carries exactly one message from its sender; the
        // rest waits for the accept. Declined chats take nothing.
        if let convo = conversation {
            if convo.effectiveStatus == .rejected {
                // The sender is never told about a decline (UX-16): they get
                // the same neutral answer as a pending request.
                actionError = declinedByMe
                    ? "You declined this request."
                    : "Wait for the other person to accept your request before sending more messages."
                return
            }
            if convo.effectiveStatus == .pending, !canSendFirstRequestMessage {
                actionError = "Wait for the other person to accept your request before sending more messages."
                return
            }
        }

        isSending = true
        defer { isSending = false }

        let replyContext = replyingTo
        replyingTo = nil

        do {
            try await ChatApiService.shared.sendMessage(
                conversationId: conversationId,
                text: text,
                replyTo: replyContext
            )
            draft = ""
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
                try? await LikeApiService.shared.setLikeStatus(
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
    /// Returns `true` when the conversation was rejected so the caller can
    /// dismiss; on failure the error is shown in place instead.
    @discardableResult
    func declineRequest() async -> Bool {
        guard let convo = conversation, convo.effectiveStatus == .pending else { return false }
        guard let myId = Auth.auth().currentUser?.uid, convo.initiatorId != myId else { return false }

        isResponding = true
        defer { isResponding = false }

        if let likeId = convo.createdFromLikeId {
            try? await LikeApiService.shared.setLikeStatus(
                likeId: likeId,
                toUserId: myId,
                status: .rejected
            )
        }

        do {
            try await ChatApiService.shared.rejectConversation(conversationId: convo.id)
            conversation?.status = .rejected
            return true
        } catch {
            actionError = "Couldn’t decline the request. Please try again."
            print("❌ [Chat] decline failed:", error.localizedDescription)
            return false
        }
    }
}
