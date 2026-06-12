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

    // MARK: - Conversation ID

    /// Deterministic conversation id for two users (order independent).
    /// Example: "uidA_uidB" with lowercased ordering.
    func conversationId(for uidA: String, and uidB: String) -> String {
        let a = uidA.lowercased()
        let b = uidB.lowercased()
        return (a < b) ? "\(a)_\(b)" : "\(b)_\(a)"
    }

    // MARK: - Create Stub (from accepted like)

    /// Creates a conversation stub when a like is accepted.
    ///
    /// Behavior:
    /// 1) Creates conversation doc if missing (with participantIds)
    /// 2) If the acceptedLike contains a non-empty `message`, it creates the first chat message
    ///    (only if there are no messages yet)
    /// 3) Updates "lastMessage*" fields on the conversation doc
    ///
    /// MVP note:
    /// - We write the first message with senderId = likerId (acceptedLike.fromUserId).
    ///   If you want stricter integrity later, we can instead create a "system" message.
    func createConversationStubIfNeeded(
        acceptedLike: TrackLike,
        receiverUserId: String
    ) async throws -> Conversation {

        guard Auth.auth().currentUser != nil else {
            throw NSError(
                domain: "ChatApiService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        let likerId = acceptedLike.fromUserId
        let convoId = conversationId(for: receiverUserId, and: likerId)
        let convoRef = db.collection(conversationsCollection).document(convoId)

        let now = Date()

        // 1) Create or touch conversation
        let snap = try await convoRef.getDocument()
        if !snap.exists {
            let convoPayload: [String: Any] = [
                "participantIds": [receiverUserId, likerId],
                "createdAt": now,
                "updatedAt": now,
                "createdFromLikeId": acceptedLike.id as Any,
                "createdFromTrackId": acceptedLike.trackId as Any,
                "status": Conversation.Status.accepted.rawValue,
                "initiatorId": likerId
            ]
            try await convoRef.setData(convoPayload, merge: true)
            print("✅ [Chat] created conversation doc \(convoId)")
        } else {
            // Always mark as accepted when this path is reached (existing pending request being accepted)
            try await convoRef.setData([
                "updatedAt": now,
                "status": Conversation.Status.accepted.rawValue
            ], merge: true)
            print("ℹ️ [Chat] conversation exists, marked accepted \(convoId)")
        }

        // 🔎 Debug check: make sure doc exists + has participantIds
        do {
            let check = try await convoRef.getDocument()
            print("🟦 [Chat] convo exists after setData=\(check.exists) data=\(check.data() ?? [:])")
        } catch {
            print("❌ [Chat] convo readback failed after setData:", error.localizedDescription)
        }

        // 2) Create first message from like comment (if present and if no messages yet)
        let likeMessage = (acceptedLike.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !likeMessage.isEmpty {
            let messagesRef = convoRef.collection("messages")

            let existing = try await messagesRef.limit(to: 1).getDocuments()
            if existing.documents.isEmpty {
                let msgRef = messagesRef.document()
                let msgPayload: [String: Any] = [
                    "senderId": likerId,
                    "text": likeMessage,
                    "createdAt": now,
                    "type": ChatMessage.MessageType.text.rawValue
                ]
                try await msgRef.setData(msgPayload)

                // Update last message info on conversation
                try await convoRef.setData([
                    "lastMessageText": likeMessage,
                    "lastMessageAt": now,
                    "lastMessageSenderId": likerId,
                    "updatedAt": now
                ], merge: true)

                print("✅ [Chat] created first message \(msgRef.documentID) for convo \(convoId)")
            } else {
                print("ℹ️ [Chat] messages already exist, not creating first message for convo \(convoId)")
            }
        }

        // 3) Return model
        let finalSnap = try await convoRef.getDocument()
        let data = finalSnap.data() ?? [:]

        if let convo = Conversation.fromFirestore(id: convoId, data: data) {
            return convo
        }

        // Fallback (should rarely happen)
        return Conversation(
            id: convoId,
            participantIds: [receiverUserId, likerId],
            createdAt: now,
            updatedAt: now,
            createdFromLikeId: acceptedLike.id,
            createdFromTrackId: acceptedLike.trackId,
            lastMessageText: likeMessage.isEmpty ? nil : likeMessage,
            lastMessageAt: likeMessage.isEmpty ? nil : now,
            lastMessageSenderId: likeMessage.isEmpty ? nil : likerId
        )
    }

    // MARK: - Message Request (Discover Like-with-message Flow)

    /// Creates a `pending` conversation with the first message taken from a like's
    /// message text. Used when user A sends a like + message to user B for the
    /// first time. The conversation appears in B's "Message Requests" inbox
    /// until B accepts it.
    ///
    /// If the conversation already exists, this is a no-op except for touching
    /// updatedAt — we never downgrade an accepted conversation back to pending.
    @discardableResult
    func createMessageRequestConversation(
        like: TrackLike,
        receiverUserId: String
    ) async throws -> Conversation {

        guard Auth.auth().currentUser != nil else {
            throw NSError(
                domain: "ChatApiService",
                code: 401,
                userInfo: [NSLocalizedDescriptionKey: "Not authenticated"]
            )
        }

        let likeMessage = (like.message ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !likeMessage.isEmpty else {
            throw NSError(
                domain: "ChatApiService",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Cannot create a request without a message"]
            )
        }

        let likerId = like.fromUserId
        let convoId = conversationId(for: receiverUserId, and: likerId)
        let convoRef = db.collection(conversationsCollection).document(convoId)
        let now = Date()

        let snap = try await convoRef.getDocument()
        if !snap.exists {
            let payload: [String: Any] = [
                "participantIds": [receiverUserId, likerId],
                "createdAt": now,
                "updatedAt": now,
                "createdFromLikeId": like.id as Any,
                "createdFromTrackId": like.trackId as Any,
                "status": Conversation.Status.pending.rawValue,
                "initiatorId": likerId,
                "lastMessageText": likeMessage,
                "lastMessageAt": now,
                "lastMessageSenderId": likerId
            ]
            try await convoRef.setData(payload, merge: true)
        } else {
            // Don't change status if already accepted
            try await convoRef.setData([
                "updatedAt": now,
                "lastMessageText": likeMessage,
                "lastMessageAt": now,
                "lastMessageSenderId": likerId
            ], merge: true)
        }

        // Create the first message if no messages exist yet
        let messagesRef = convoRef.collection("messages")
        let existing = try await messagesRef.limit(to: 1).getDocuments()
        if existing.documents.isEmpty {
            let msgRef = messagesRef.document()
            try await msgRef.setData([
                "senderId": likerId,
                "text": likeMessage,
                "createdAt": now,
                "type": ChatMessage.MessageType.text.rawValue
            ])
        }

        let finalSnap = try await convoRef.getDocument()
        let data = finalSnap.data() ?? [:]
        if let convo = Conversation.fromFirestore(id: convoId, data: data) {
            return convo
        }
        return Conversation(
            id: convoId,
            participantIds: [receiverUserId, likerId],
            createdAt: now,
            updatedAt: now,
            createdFromLikeId: like.id,
            createdFromTrackId: like.trackId,
            lastMessageText: likeMessage,
            lastMessageAt: now,
            lastMessageSenderId: likerId,
            status: .pending,
            initiatorId: likerId
        )
    }

    /// Marks an existing conversation as accepted. Used both when a like is
    /// accepted from the Likes inbox and when the recipient accepts the
    /// message request directly from the chat view.
    func acceptConversation(conversationId: String) async throws {
        let ref = db.collection(conversationsCollection).document(conversationId)
        try await ref.setData([
            "status": Conversation.Status.accepted.rawValue,
            "updatedAt": Date()
        ], merge: true)
    }

    /// Marks a pending message-request conversation as rejected so it no
    /// longer shows up in the recipient's requests list.
    func rejectConversation(conversationId: String) async throws {
        let ref = db.collection(conversationsCollection).document(conversationId)
        try await ref.setData([
            "status": Conversation.Status.rejected.rawValue,
            "updatedAt": Date()
        ], merge: true)
    }

    /// Fetches a single conversation. Returns nil if it doesn't exist.
    func fetchConversation(conversationId: String) async throws -> Conversation? {
        let snap = try await db.collection(conversationsCollection)
            .document(conversationId)
            .getDocument()
        guard snap.exists, let data = snap.data() else { return nil }
        return Conversation.fromFirestore(id: conversationId, data: data)
    }

    // MARK: - Send Message (Discover Like Flow)

    func sendMessage(
        from senderId: String,
        to receiverId: String,
        text: String,
        createdFromTrackId: String?,
        createdFromLikeId: String?
    ) async throws {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let convoId = conversationId(for: senderId, and: receiverId)
        let convoRef = db.collection(conversationsCollection).document(convoId)
        let now = Date()

        let snapshot = try await convoRef.getDocument()
        if !snapshot.exists {
            let payload: [String: Any] = [
                "participantIds": [senderId, receiverId],
                "createdAt": now,
                "updatedAt": now,
                "createdFromLikeId": createdFromLikeId as Any,
                "createdFromTrackId": createdFromTrackId as Any
            ]
            try await convoRef.setData(payload, merge: true)
        } else {
            try await convoRef.setData(["updatedAt": now], merge: true)
        }

        let messageRef = convoRef.collection("messages").document()
        let messagePayload: [String: Any] = [
            "senderId": senderId,
            "text": trimmed,
            "createdAt": now,
            "type": ChatMessage.MessageType.text.rawValue
        ]
        try await messageRef.setData(messagePayload)

        try await convoRef.setData([
            "lastMessageText": trimmed,
            "lastMessageAt": now,
            "lastMessageSenderId": senderId,
            "updatedAt": now
        ], merge: true)
    }
}
