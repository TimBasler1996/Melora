//
//  ChatMessage.swift
//  SocialSound
//
//  Created by Tim Basler on 06.01.2026.
//


import Foundation
import FirebaseFirestore

struct ChatMessage: Identifiable, Codable, Equatable {

    enum MessageType: String, Codable {
        case text
        case system
    }

    var id: String
    var senderId: String
    var text: String
    var createdAt: Date
    var type: MessageType

    static func fromFirestore(id: String, data: [String: Any]) -> ChatMessage? {
        guard
            let senderId = data["senderId"] as? String,
            let text = data["text"] as? String
        else { return nil }

        let createdAt: Date = {
            if let ts = data["createdAt"] as? Timestamp { return ts.dateValue() }
            if let d = data["createdAt"] as? Date { return d }
            return Date()
        }()

        let typeRaw = data["type"] as? String
        let type = typeRaw.flatMap(MessageType.init(rawValue:)) ?? .text

        return ChatMessage(
            id: id,
            senderId: senderId,
            text: text,
            createdAt: createdAt,
            type: type
        )
    }
}
