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

    /// Snapshot of the message being replied to, denormalized onto the new
    /// message so the chat can render the quoted bubble without an extra fetch.
    struct ReplyContext: Codable, Equatable {
        var messageId: String
        var senderId: String
        var textPreview: String
    }

    var id: String
    var senderId: String
    var text: String
    var createdAt: Date
    var type: MessageType

    var replyTo: ReplyContext?

    /// Reactions keyed by user id → emoji. One reaction per user per message.
    var reactions: [String: String]?

    /// A song sent with the message ("what I’m playing right now"). The text
    /// carries a plain "🎵 Title – Artist" for previews, pushes and clients
    /// that don’t know the attachment.
    var track: Track?

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

        let replyTo: ReplyContext? = {
            guard let dict = data["replyTo"] as? [String: Any],
                  let messageId = dict["messageId"] as? String,
                  let senderId = dict["senderId"] as? String,
                  let textPreview = dict["textPreview"] as? String else { return nil }
            return ReplyContext(messageId: messageId, senderId: senderId, textPreview: textPreview)
        }()

        let reactions = data["reactions"] as? [String: String]

        let track: Track? = {
            guard let dict = data["track"] as? [String: Any],
                  let trackId = dict["id"] as? String, !trackId.isEmpty,
                  let title = dict["title"] as? String,
                  let artist = dict["artist"] as? String else { return nil }
            return Track(
                id: trackId,
                title: title,
                artist: artist,
                album: dict["album"] as? String,
                artworkURL: (dict["artworkURL"] as? String).flatMap(URL.init(string:)),
                durationMs: dict["durationMs"] as? Int
            )
        }()

        return ChatMessage(
            id: id,
            senderId: senderId,
            text: text,
            createdAt: createdAt,
            type: type,
            replyTo: replyTo,
            reactions: reactions,
            track: track
        )
    }
}
