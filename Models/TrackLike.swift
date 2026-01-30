//
//  TrackLike.swift
//  SocialSound
//

import Foundation
import FirebaseFirestore

struct TrackLike: Identifiable, Codable, Equatable {

    enum Status: String, Codable {
        case pending
        case accepted
        case rejected
    }

    var id: String

    var fromUserId: String
    var toUserId: String

    var trackId: String
    var trackTitle: String
    var trackArtist: String
    var trackAlbum: String?
    var trackArtworkURL: String?

    var sessionId: String?
    var createdAt: Date
    var placeLabel: String?
    var latitude: Double?
    var longitude: Double?
    var fromUserDisplayName: String?
    var fromUserAvatarURL: String?

    // ✅ NEW (optional, backward compatible)
    var message: String?
    var status: Status?

    var createdAtFormatted: String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: createdAt)
    }

    static func fromFirestore(id: String, data: [String: Any]) -> TrackLike? {
        guard
            let trackId = data["trackId"] as? String,
            let trackTitle = data["trackTitle"] as? String,
            let trackArtist = data["trackArtist"] as? String,
            let fromUserId = data["fromUserId"] as? String,
            let toUserId = data["toUserId"] as? String
        else { return nil }

        let createdAt: Date = {
            if let ts = data["createdAt"] as? Timestamp { return ts.dateValue() }
            if let d = data["createdAt"] as? Date { return d }
            return Date()
        }()

        let statusRaw = data["status"] as? String
        let status = statusRaw.flatMap(Status.init(rawValue:))

        return TrackLike(
            id: id,
            fromUserId: fromUserId,
            toUserId: toUserId,
            trackId: trackId,
            trackTitle: trackTitle,
            trackArtist: trackArtist,
            trackAlbum: data["trackAlbum"] as? String,
            trackArtworkURL: data["trackArtworkURL"] as? String,
            sessionId: data["sessionId"] as? String,
            createdAt: createdAt,
            placeLabel: data["placeLabel"] as? String,
            latitude: data["latitude"] as? Double,
            longitude: data["longitude"] as? Double,
            fromUserDisplayName: data["fromUserDisplayName"] as? String,
            fromUserAvatarURL: data["fromUserAvatarURL"] as? String,
            message: data["message"] as? String,
            status: status
        )
    }
}

