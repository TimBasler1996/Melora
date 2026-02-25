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

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    func start(conversationId: String) {
        stop()

        isLoading = true
        errorMessage = nil
        messages = []

        Task {
            do {
                // ✅ First ensure conversation exists and is readable
                let convoSnap = try await db.collection("conversations").document(conversationId).getDocument()
                if !convoSnap.exists {
                    self.isLoading = false
                    self.errorMessage = "Conversation not found."
                    print("❌ [Chat] conversation does not exist:", conversationId)
                    return
                }

                // ✅ Now start listening to messages (rules can now resolve get(conversation))
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

                // Mark conversation as read when opened
                await markAsRead(conversationId: conversationId)

            } catch {
                self.isLoading = false
                self.errorMessage = error.localizedDescription
                print("❌ [Chat] start failed:", error.localizedDescription)
            }
        }
    }

    func stop() {
        listener?.remove()
        listener = nil
    }

    func markAsRead(conversationId: String) async {
        guard let myId = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("conversations").document(conversationId).setData([
                "lastReadAt.\(myId)": Timestamp(date: Date())
            ], merge: true)
        } catch {
            print("❌ [Chat] markAsRead failed:", error.localizedDescription)
        }
    }

    func send(conversationId: String) async {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        guard let myId = Auth.auth().currentUser?.uid else { return }

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
}

