import Foundation
import FirebaseFirestore

/// Firestore user model: `users/{uid}`
/// - Document ID = Firebase Auth UID
/// - `spotifyId` is stored as a field
struct AppUser: Identifiable, Codable, Equatable {

    // MARK: - Nested

    enum AvatarSource: String, Codable {
        case spotify
        case uploaded
        case unknown
    }

    // MARK: - Identity

    /// Firebase UID (Document ID)
    var uid: String

    /// Convenience for SwiftUI lists
    var id: String { uid }

    /// Spotify user id (stored in Firestore field)
    var spotifyId: String?

    // MARK: - Profile

    var displayName: String
    var firstName: String?
    var lastName: String?

    var countryCode: String?
    var age: Int?
    var birthday: Date? // ✅ Added for birthday display
    var gender: String?
    var city: String? // ✅ Added city field (alias for hometown in some contexts)
    var hometown: String?
    var musicTaste: String?

    // MARK: - Photos

    var avatarURL: String?
    var avatarSource: AvatarSource?
    var photoURLs: [String]?

    // MARK: - Presence / Broadcast

    var isBroadcasting: Bool?
    var currentTrack: Track?
    var lastLocation: LocationPoint?
    var lastActiveAt: Date?
    var broadcastMinutesTotal: Int?

    // MARK: - Meta

    var profileCompleted: Bool?
    var createdAt: Date?
    var updatedAt: Date?

    // MARK: - Init (stabil: Reihenfolge exakt so wie wir sie überall nutzen)

    init(
        uid: String,
        spotifyId: String? = nil,
        displayName: String,
        avatarURL: String? = nil,
        avatarSource: AvatarSource? = nil,
        age: Int? = nil,
        birthday: Date? = nil,
        city: String? = nil,
        hometown: String? = nil,
        musicTaste: String? = nil,
        countryCode: String? = nil,
        gender: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil,
        photoURLs: [String]? = nil,
        isBroadcasting: Bool? = nil,
        currentTrack: Track? = nil,
        broadcastMinutesTotal: Int? = nil,
        profileCompleted: Bool? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil,
        lastActiveAt: Date? = nil,
        lastLocation: LocationPoint? = nil
    ) {
        self.uid = uid
        self.spotifyId = spotifyId
        self.displayName = displayName

        self.avatarURL = avatarURL
        self.avatarSource = avatarSource

        self.age = age
        self.birthday = birthday
        self.city = city
        self.hometown = hometown
        self.musicTaste = musicTaste
        self.countryCode = countryCode
        self.gender = gender

        self.firstName = firstName
        self.lastName = lastName

        self.photoURLs = photoURLs
        self.isBroadcasting = isBroadcasting
        self.currentTrack = currentTrack
        self.broadcastMinutesTotal = broadcastMinutesTotal
        self.profileCompleted = profileCompleted

        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.lastActiveAt = lastActiveAt
        self.lastLocation = lastLocation
    }

    // MARK: - Helpers

    var initials: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: " ")
        if let first = parts.first {
            let a = String(first.prefix(1))
            if parts.count >= 2, let second = parts.dropFirst().first {
                let b = String(second.prefix(1))
                return (a + b).uppercased()
            }
            return a.uppercased()
        }
        return "?"
    }

    var isCompleteDerived: Bool {
        let nameOK = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPhotos = (photoURLs?.count ?? 0) >= 2
        return nameOK && hasPhotos
    }

    // MARK: - Factories

    static func fromSpotifyProfile(
        uid: String,
        spotifyId: String,
        displayName: String,
        countryCode: String?,
        avatarURL: String?
    ) -> AppUser {
        AppUser(
            uid: uid,
            spotifyId: spotifyId,
            displayName: displayName,
            avatarURL: avatarURL,
            avatarSource: .spotify,
            countryCode: countryCode,
            isBroadcasting: false,
            profileCompleted: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func fromFirestore(uid: String, data: [String: Any]) -> AppUser {

        func intFromAny(_ any: Any?) -> Int? {
            if let v = any as? Int { return v }
            if let v = any as? Int64 { return Int(v) }
            if let v = any as? Double { return Int(v) }
            return nil
        }

        func boolValue(_ key: String) -> Bool? { data[key] as? Bool }
        func stringValue(_ key: String) -> String? { data[key] as? String }
        func ts(_ key: String) -> Date? { (data[key] as? Timestamp)?.dateValue() }

        let lastLocation: LocationPoint? = {
            guard let dict = data["lastLocation"] as? [String: Any],
                  let lat = dict["latitude"] as? Double,
                  let lon = dict["longitude"] as? Double else { return nil }
            return LocationPoint(latitude: lat, longitude: lon)
        }()

        let currentTrack: Track? = {
            guard let dict = data["currentTrack"] as? [String: Any] else { return nil }
            guard let id = dict["id"] as? String,
                  let title = dict["title"] as? String,
                  let artist = dict["artist"] as? String else { return nil }

            let album = dict["album"] as? String
            let artworkURL = (dict["artworkURL"] as? String).flatMap(URL.init(string:))
            let durationMs = intFromAny(dict["durationMs"])

            return Track(
                id: id,
                title: title,
                artist: artist,
                album: album,
                artworkURL: artworkURL,
                durationMs: durationMs
            )
        }()

        let photoURLs: [String]? = (data["photoURLs"] as? [String])

        let avatarSourceRaw = stringValue("avatarSource")
        let avatarSource = avatarSourceRaw.flatMap(AvatarSource.init(rawValue:)) ?? .unknown

        // ✅ Smart displayName resolution:
        // 1. Use displayName if available
        // 2. Otherwise, construct from firstName + lastName
        // 3. Fall back to "Unknown" only if nothing else is available
        let firstName = stringValue("firstName")
        let lastName = stringValue("lastName")
        let explicitDisplayName = stringValue("displayName")
        
        let resolvedDisplayName: String = {
            // First try explicit displayName
            if let name = explicitDisplayName, !name.isEmpty, name != "Unknown" {
                return name
            }
            
            // Then try to construct from first/last name
            let first = firstName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let last = lastName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            
            if !first.isEmpty && !last.isEmpty {
                return "\(first) \(last)"
            } else if !first.isEmpty {
                return first
            } else if !last.isEmpty {
                return last
            }
            
            // Final fallback
            return "Unknown"
        }()
        
        return AppUser(
            uid: uid,
            spotifyId: stringValue("spotifyId"),
            displayName: resolvedDisplayName,
            avatarURL: stringValue("avatarURL"),
            avatarSource: avatarSource,
            age: intFromAny(data["age"]),
            birthday: ts("birthday"), // ✅ Parse birthday from Firestore
            city: stringValue("city"), // ✅ Parse city from Firestore
            hometown: stringValue("hometown"),
            musicTaste: stringValue("musicTaste"),
            countryCode: stringValue("countryCode"),
            gender: stringValue("gender"),
            firstName: firstName,
            lastName: lastName,
            photoURLs: photoURLs,
            isBroadcasting: boolValue("isBroadcasting"),
            currentTrack: currentTrack,
            broadcastMinutesTotal: intFromAny(data["broadcastMinutesTotal"]),
            profileCompleted: boolValue("profileCompleted"),
            createdAt: ts("createdAt"),
            updatedAt: ts("updatedAt"),
            lastActiveAt: ts("lastActiveAt"),
            lastLocation: lastLocation
        )
    }
}

