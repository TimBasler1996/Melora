import Foundation

/// Represents a live or past broadcast session in SocialSound.
struct Session: Identifiable, Equatable {
    var id: String
    var user: User
    var track: Track
    var location: LocationPoint
    var createdAt: Date
    /// Last time this session was updated (track/location/heartbeat).
    var updatedAt: Date
    var isActive: Bool
    var likeCount: Int
    
    init(
        id: String,
        user: User,
        track: Track,
        location: LocationPoint,
        createdAt: Date,
        updatedAt: Date? = nil,
        isActive: Bool,
        likeCount: Int
    ) {
        self.id = id
        self.user = user
        self.track = track
        self.location = location
        self.createdAt = createdAt
        // Wenn kein updatedAt angegeben ist → gleich wie createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.isActive = isActive
        self.likeCount = likeCount
    }
    
    /// Returns a copy of the session with an updated track.
    func updating(track newTrack: Track) -> Session {
        var copy = self
        copy.track = newTrack
        copy.updatedAt = Date()
        return copy
    }
    
    /// Returns a copy of the session with an updated location.
    func updating(location newLocation: LocationPoint) -> Session {
        var copy = self
        copy.location = newLocation
        copy.updatedAt = Date()
        return copy
    }
    
    /// Returns a copy with only updatedAt "touched" to now.
    func touching() -> Session {
        var copy = self
        copy.updatedAt = Date()
        return copy
    }
}

