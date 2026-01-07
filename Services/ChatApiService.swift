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
                "createdFromTrackId": acceptedLike.trackId as Any
            ]
            try await convoRef.setData(convoPayload, merge: true)
            print("✅ [Chat] created conversation doc \(convoId)")
        } else {
            try await convoRef.setData(["updatedAt": now], merge: true)
            print("ℹ️ [Chat] conversation exists, updatedAt touched \(convoId)")
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
}

