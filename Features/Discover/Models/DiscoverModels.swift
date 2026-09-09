import Foundation

struct DiscoverUser: Identifiable, Codable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let age: Int?
    let city: String
    let gender: String?
    let countryCode: String?
    let heroPhotoURL: String?
    let profilePhotoURL: String?
    let photoURLs: [String]

    var displayName: String {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = [trimmedFirst, trimmedLast].filter { !$0.isEmpty }.joined(separator: " ")
        return combined.isEmpty ? "New member" : combined
    }

    var primaryPhotoURL: String? {
        if let hero = heroPhotoURL, !hero.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return hero
        }
        if let profilePhotoURL, !profilePhotoURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return profilePhotoURL
        }
        if let first = photoURLs.first, !first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return first
        }
        return nil
    }

    var ageText: String {
        age.map(String.init) ?? "—"
    }

    var locationText: String {
        let trimmed = city.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Somewhere" : trimmed
    }
}

struct DiscoverTrack: Identifiable, Codable, Equatable {
    let id: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: String?
    let spotifyTrackURL: String?

    var artworkURLValue: URL? {
        artworkURL.flatMap(URL.init(string:))
    }

    var spotifyURLValue: URL? {
        spotifyTrackURL.flatMap(URL.init(string:))
    }
}

struct DiscoverBroadcast: Identifiable, Codable, Equatable {
    let id: String
    let user: DiscoverUser
    let track: DiscoverTrack
    let broadcastedAt: Date
    let location: LocationPoint?
    var distanceMeters: Int?

    /// `true` while the person is broadcasting right now. Broadcasts that
    /// ended (or went stale) within the last day stay around as "recently
    /// live" so Discover is never empty in a quiet moment.
    var isLive: Bool = true

    /// When the broadcast was last refreshed (live) or ended (recent).
    var lastSeenAt: Date = Date()

    /// Human "3 h ago" style label for recently-live rows.
    var lastSeenText: String {
        let seconds = Date().timeIntervalSince(lastSeenAt)
        if seconds < 90 { return "just now" }
        let minutes = Int(seconds / 60)
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = Int(seconds / 3600)
        if hours < 24 { return "\(hours) h ago" }
        return "yesterday"
    }
}
