//
//  Conversation.swift
//  SocialSound
//
//  Created by Tim Basler on 06.01.2026.
//


import Foundation
import FirebaseFirestore

struct Conversation: Identifiable, Codable, Equatable {
    var id: String

    var participantIds: [String]
    var createdAt: Date
    var updatedAt: Date

    var createdFromLikeId: String?
    var createdFromTrackId: String?

    var lastMessageText: String?
    var lastMessageAt: Date?
    var lastMessageSenderId: String?

    static func fromFirestore(id: String, data: [String: Any]) -> Conversation? {
        guard let participantIds = data["participantIds"] as? [String] else { return nil }

        func date(_ key: String) -> Date? {
            if let ts = data[key] as? Timestamp { return ts.dateValue() }
            if let d = data[key] as? Date { return d }
            return nil
        }

        return Conversation(
            id: id,
            participantIds: participantIds,
            createdAt: date("createdAt") ?? Date(),
            updatedAt: date("updatedAt") ?? Date(),
            createdFromLikeId: data["createdFromLikeId"] as? String,
            createdFromTrackId: data["createdFromTrackId"] as? String,
            lastMessageText: data["lastMessageText"] as? String,
            lastMessageAt: date("lastMessageAt"),
            lastMessageSenderId: data["lastMessageSenderId"] as? String
        )
    }
}
