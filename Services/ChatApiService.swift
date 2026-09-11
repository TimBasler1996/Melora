//
//  ChatApiService.swift
//  SocialSound
//
//  Created by Tim Basler on 06.01.2026.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

actor ChatApiService {

    static let shared = ChatApiService()

    private let db = Firestore.firestore()
    private let conversationsCollection = "conversations"

    enum ChatError: LocalizedError {
        case notAuthenticated
        case emptyMessage
        case requestDeclined

        var errorDescription: String? {
            switch self {
            case .notAuthenticated: return "You’re not signed in."
            case .emptyMessage: return "Write something first."
            // Deliberately neutral: the sender is never told a request was declined.
            case .requestDeclined: return "You’ve already reached out to them. If they’re interested, they’ll get back to you."
            }
        }
    }

    // MARK: - Conversation ID

    /// Deterministic conversation id for two users (order independent).
    /// Example: "uidA_uidB" with lowercased ordering.
    nonisolated func conversationId(for uidA: String, and uidB: String) -> String {
        let a = uidA.lowercased()
        let b = uidB.lowercased()
        return (a < b) ? "\(a)_\(b)" : "\(b)_\(a)"
    }

    // MARK: - Create Stub (from accepted like)

    /// Ensures an *accepted* conversation exists between the receiver of a like
    /// and the liker. Called when a like is accepted (by the receiver) or when
    /// a like auto-accepts because of a prior relationship (by the liker).
    ///
    /// The like's message, if any, is appended as a chat message only when the
    /// caller *is* the liker: security rules only allow writing messages with
    /// your own `senderId`. In the normal flow the message was already written
    /// at like time via `deliverLikeMessage`, so nothing is lost.
    func createConversationStubIfNeeded(
        acceptedLike: TrackLike,
        receiverUserId: String
    ) async throws -> Conversation {

        guard let callerId = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }

        let likerId = acceptedLike.fromUserId
        let convoId = conversationId(for: receiverUserId, and: likerId)
        let convoRef = db.collection(conversationsCollection).document(convoId)

        let snap = try await convoRef.getDocument()
        if !snap.exists {
            try await convoRef.setData([
                "participantIds": [receiverUserId, likerId],
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "createdFromLikeId": acceptedLike.id as Any,
                "createdFromTrackId": acceptedLike.trackId as Any,
                "status": Conversation.Status.accepted.rawValue,
                "initiatorId": likerId
            ], merge: true)
        } else if callerId == receiverUserId {
            // Only the recipient may flip the status (rules enforce this too);
            // the liker just touches the conversation.
            try await convoRef.setData([
                "updatedAt": FieldValue.serverTimestamp(),
                "status": Conversation.Status.accepted.rawValue
            ], merge: true)
        } else {
            try await convoRef.setData([
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
        }

        let likeMessage = (acceptedLike.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !likeMessage.isEmpty, callerId == likerId {
            let existing = try await convoRef.collection("messages").limit(to: 1).getDocuments()
            if existing.documents.isEmpty {
                try await appendMessage(to: convoRef, senderId: likerId, text: likeMessage)
            }
        }

        return try await loadConversation(ref: convoRef, id: convoId, fallbackParticipants: [receiverUserId, likerId])
    }

    // MARK: - Deliver a Discover message

    /// Delivers the message typed on a Discover card into the conversation
    /// between the current user (the liker) and the receiver.
    ///
    /// - New conversation: created as a `pending` message request, or directly
    ///   `accepted` when the like itself auto-accepted (prior relationship).
    /// - Existing accepted or pending conversation: the message is appended as
    ///   a normal chat message and the preview fields are refreshed.
    /// - Existing rejected conversation: throws `ChatError.requestDeclined` so
    ///   the sender is told instead of the message vanishing silently.
    @discardableResult
    func deliverLikeMessage(
        like: TrackLike,
        text: String,
        receiverUserId: String
    ) async throws -> Conversation {

        guard let senderId = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChatError.emptyMessage }

        let convoId = conversationId(for: receiverUserId, and: senderId)
        let convoRef = db.collection(conversationsCollection).document(convoId)

        let snap = try await convoRef.getDocument()
        if !snap.exists {
            let initialStatus: Conversation.Status = like.status == .accepted ? .accepted : .pending
            try await convoRef.setData([
                "participantIds": [receiverUserId, senderId],
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "createdFromLikeId": like.id as Any,
                "createdFromTrackId": like.trackId as Any,
                "status": initialStatus.rawValue,
                "initiatorId": senderId
            ], merge: true)
        } else {
            let existingStatus = (snap.data()?["status"] as? String)
                .flatMap(Conversation.Status.init(rawValue:)) ?? .accepted
            if existingStatus == .rejected {
                throw ChatError.requestDeclined
            }
        }

        try await appendMessage(to: convoRef, senderId: senderId, text: trimmed)

        return try await loadConversation(ref: convoRef, id: convoId, fallbackParticipants: [receiverUserId, senderId])
    }

    // MARK: - Recreate after delete

    /// Starts a new message request with `peerId` when the previous
    /// conversation was deleted. Returns the (possibly already existing)
    /// conversation.
    func createRequestConversation(with peerId: String) async throws -> Conversation {
        guard let me = Auth.auth().currentUser?.uid else { throw ChatError.notAuthenticated }
        let convoId = conversationId(for: me, and: peerId)
        let convoRef = db.collection(conversationsCollection).document(convoId)

        let snap = try await convoRef.getDocument()
        if !snap.exists {
            try await convoRef.setData([
                "participantIds": [me, peerId],
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp(),
                "status": Conversation.Status.pending.rawValue,
                "initiatorId": me
            ], merge: true)
        }
        return try await loadConversation(ref: convoRef, id: convoId, fallbackParticipants: [me, peerId])
    }

    // MARK: - Status changes

    /// Marks an existing conversation as accepted. Used both when a like is
    /// accepted from the Likes inbox and when the recipient accepts the
    /// message request directly from the chat view.
    func acceptConversation(conversationId: String) async throws {
        try await setStatus(.accepted, conversationId: conversationId)
    }

    /// Marks a pending message-request conversation as rejected so it no
    /// longer shows up in the recipient's requests list.
    func rejectConversation(conversationId: String) async throws {
        try await setStatus(.rejected, conversationId: conversationId)
    }

    /// Mirrors a like status change onto the linked conversation, but only
    /// while that conversation is still a *pending* request. Ignoring a plain
    /// like must never close a chat the two people already have.
    func mirrorLikeStatus(_ status: Conversation.Status, between uidA: String, and uidB: String) async {
        let convoId = conversationId(for: uidA, and: uidB)
        let convoRef = db.collection(conversationsCollection).document(convoId)
        guard let snap = try? await convoRef.getDocument(), snap.exists else { return }
        let current = (snap.data()?["status"] as? String).flatMap(Conversation.Status.init(rawValue:)) ?? .accepted
        guard current == .pending else { return }
        try? await setStatus(status, conversationId: convoId)
    }

    private func setStatus(_ status: Conversation.Status, conversationId: String) async throws {
        try await db.collection(conversationsCollection).document(conversationId).setData([
            "status": status.rawValue,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true)
    }

    // MARK: - Delete

    /// Deletes a conversation. Its `messages` subcollection is removed by the
    /// `onConversationDeleted` Cloud Function (clients cannot delete subcollections).
    func deleteConversation(conversationId: String) async throws {
        try await db.collection(conversationsCollection).document(conversationId).delete()
    }

    // MARK: - Messages

    /// Sends a regular chat message. Used by the chat thread.
    func sendMessage(
        conversationId: String,
        text: String,
        replyTo: ChatMessage? = nil
    ) async throws {
        guard let senderId = Auth.auth().currentUser?.uid else {
            throw ChatError.notAuthenticated
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ChatError.emptyMessage }

        let convoRef = db.collection(conversationsCollection).document(conversationId)
        try await appendMessage(to: convoRef, senderId: senderId, text: trimmed, replyTo: replyTo)
    }

    /// Writes one message and refreshes the conversation's preview fields.
    /// Server timestamps everywhere so ordering, unread state and "Seen" never
    /// depend on two devices' clocks agreeing.
    private func appendMessage(
        to convoRef: DocumentReference,
        senderId: String,
        text: String,
        replyTo: ChatMessage? = nil
    ) async throws {
        var payload: [String: Any] = [
            "senderId": senderId,
            "text": text,
            "createdAt": FieldValue.serverTimestamp(),
            "type": ChatMessage.MessageType.text.rawValue
        ]
        if let replyTo {
            payload["replyTo"] = [
                "messageId": replyTo.id,
                "senderId": replyTo.senderId,
                "textPreview": String(replyTo.text.prefix(120))
            ]
        }

        let batch = db.batch()
        batch.setData(payload, forDocument: convoRef.collection("messages").document())
        batch.setData([
            "lastMessageText": text,
            "lastMessageAt": FieldValue.serverTimestamp(),
            "lastMessageSenderId": senderId,
            "updatedAt": FieldValue.serverTimestamp()
        ], forDocument: convoRef, merge: true)
        try await batch.commit()
    }

    private func loadConversation(
        ref: DocumentReference,
        id: String,
        fallbackParticipants: [String]
    ) async throws -> Conversation {
        let snap = try await ref.getDocument()
        if let convo = Conversation.fromFirestore(id: id, data: snap.data() ?? [:]) {
            return convo
        }
        let now = Date()
        return Conversation(
            id: id,
            participantIds: fallbackParticipants,
            createdAt: now,
            updatedAt: now
        )
    }
}
