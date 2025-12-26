import Foundation

struct TrackLike: Identifiable {
    let id: String
    let fromUserId: String
    let toUserId: String
    
    let trackId: String
    let trackTitle: String
    let trackArtist: String
    let trackAlbum: String?
    
    let sessionId: String
    let createdAt: Date
    let placeLabel: String?
    
    let latitude: Double?
    let longitude: Double?
    
    // Infos zum Liker
    let fromUserDisplayName: String?
    let fromUserAvatarURL: String?
    
    // Track-Artwork
    let trackArtworkURL: String?
}
