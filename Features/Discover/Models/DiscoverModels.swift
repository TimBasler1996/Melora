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
        return combined.isEmpty ? "Unknown" : combined
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
        return trimmed.isEmpty ? "Unknown" : trimmed
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
}
