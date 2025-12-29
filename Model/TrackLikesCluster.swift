//
//  TrackLikesCluster.swift
//  SocialSound
//
//  Created by Tim Basler on 21.11.2025.
//


import Foundation

/// Ein Cluster von Likes für einen bestimmten Track.
/// Wird in der LikesInboxView als Zeile angezeigt.
struct TrackLikesCluster: Identifiable {
    let id: String
    
    let trackTitle: String
    let trackArtist: String
    let trackAlbum: String?
    
    let likeCount: Int
    let lastLikeAt: Date
    
    /// Alle einzelnen Likes für diesen Track.
    let likes: [TrackLike]

    /// Optional: Artwork-URL für den Track (z. B. vom ersten Like übernommen).
    let trackArtworkURL: String?

    /// Convenience: Baut ein `Track` Modell für Detail-Views.
    var asTrack: Track {
        Track(
            id: id,
            title: trackTitle,
            artist: trackArtist,
            album: trackAlbum,
            artworkURL: trackArtworkURL.flatMap(URL.init(string:)),
            durationMs: nil
        )
    }
}