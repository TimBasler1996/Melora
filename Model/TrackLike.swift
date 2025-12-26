//
//  TrackLike.swift
//  SocialSound
//

import Foundation
import FirebaseFirestore

struct TrackLike: Identifiable, Codable, Equatable {
    var id: String

    var trackId: String
    var trackTitle: String
    var trackArtist: String
    var trackAlbum: String?
    var trackArtworkURL: String?

    var fromUserId: String
    var createdAt: Date

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
            let ts = data["createdAt"] as? Timestamp
        else { return nil }

        return TrackLike(
            id: id,
            trackId: trackId,
            trackTitle: trackTitle,
            trackArtist: trackArtist,
            trackAlbum: data["trackAlbum"] as? String,
            trackArtworkURL: data["trackArtworkURL"] as? String,
            fromUserId: fromUserId,
            createdAt: ts.dateValue()
        )
    }
}

