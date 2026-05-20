import Foundation
import FirebaseAuth
import FirebaseFirestore

@MainActor
final class ChatViewModel: ObservableObject {

    @Published var messages: [ChatMessage] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    @Published var draft: String = ""
    @Published var isSending: Bool = false

    @Published var conversation: Conversation?
    @Published var isResponding: Bool = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private var conversationListener: ListenerRegistration?

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
                self.conversation = Conversation.fromFirestore(id: conversationId, data: data)
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
            errorMessage = "Wait for the other user to accept your request before sending more messages."
            return
        }

        isSending = true
        defer { isSending = false }

        do {
            let now = Date()

            let convoRef = db.collection("conversations").document(conversationId)
            let msgRef = convoRef.collection("messages").document()

            try await msgRef.setData([
                "senderId": myId,
                "text": text,
                "createdAt": now,
                "type": ChatMessage.MessageType.text.rawValue
            ])

            try await convoRef.setData([
                "lastMessageText": text,
                "lastMessageAt": now,
                "lastMessageSenderId": myId,
                "updatedAt": now
            ], merge: true)

            draft = ""
            print("✅ [Chat] sent message \(msgRef.documentID)")
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [Chat] send failed:", error.localizedDescription)
        }
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
        } catch {
            errorMessage = error.localizedDescription
            print("❌ [Chat] accept failed:", error.localizedDescription)
        }
    }

    /// Decline a pending message request: mark the underlying like as rejected.
    /// The conversation doc stays in the rejected state via its existing status.
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
    }
}
