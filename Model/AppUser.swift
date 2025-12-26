import Foundation
import FirebaseFirestore

/// Firestore user model: `users/{uid}`
/// - Document ID = Firebase Auth UID
/// - spotifyId is stored as field
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
    
    /// Optional (some screens still reference these)
    var firstName: String?
    var lastName: String?
    
    var countryCode: String?
    var age: Int?
    var gender: String?
    var hometown: String?
    var musicTaste: String?
    
    // MARK: - Photos
    
    var avatarURL: String?
    var avatarSource: AvatarSource?
    var photoURLs: [String]?
    
    // MARK: - Presence
    
    var isBroadcasting: Bool?
    var lastLocation: LocationPoint?
    var lastActiveAt: Date?
    
    // MARK: - Meta
    
    var profileCompleted: Bool?
    var createdAt: Date?
    var updatedAt: Date?
    
    // MARK: - Init (stable labeled init – avoids “argument must precede …”)
    
    init(
        uid: String,
        spotifyId: String? = nil,
        displayName: String,
        firstName: String? = nil,
        lastName: String? = nil,
        countryCode: String? = nil,
        age: Int? = nil,
        gender: String? = nil,
        hometown: String? = nil,
        musicTaste: String? = nil,
        avatarURL: String? = nil,
        avatarSource: AvatarSource? = nil,
        photoURLs: [String]? = nil,
        isBroadcasting: Bool? = nil,
        lastLocation: LocationPoint? = nil,
        lastActiveAt: Date? = nil,
        profileCompleted: Bool? = nil,
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.uid = uid
        self.spotifyId = spotifyId
        self.displayName = displayName
        self.firstName = firstName
        self.lastName = lastName
        self.countryCode = countryCode
        self.age = age
        self.gender = gender
        self.hometown = hometown
        self.musicTaste = musicTaste
        self.avatarURL = avatarURL
        self.avatarSource = avatarSource
        self.photoURLs = photoURLs
        self.isBroadcasting = isBroadcasting
        self.lastLocation = lastLocation
        self.lastActiveAt = lastActiveAt
        self.profileCompleted = profileCompleted
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
    
    /// Derived completion (used in several views)
    var isCompleteDerived: Bool {
        let nameOK = !displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPhotos = (photoURLs?.count ?? 0) >= 2
        return nameOK && hasPhotos
    }
    
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
            countryCode: countryCode,
            avatarURL: avatarURL,
            avatarSource: .spotify,
            isBroadcasting: false,
            profileCompleted: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    }

    static func fromFirestore(uid: String, data: [String: Any]) -> AppUser {

        func intValue(_ key: String) -> Int? {
            if let v = data[key] as? Int { return v }
            if let v = data[key] as? Int64 { return Int(v) }
            if let v = data[key] as? Double { return Int(v) }
            return nil
        }

        func boolValue(_ key: String) -> Bool? {
            data[key] as? Bool
        }

        func stringValue(_ key: String) -> String? {
            data[key] as? String
        }

        func ts(_ key: String) -> Date? {
            (data[key] as? Timestamp)?.dateValue()
        }

        let lastLocation: LocationPoint? = {
            guard let dict = data["lastLocation"] as? [String: Any],
                  let lat = dict["latitude"] as? Double,
                  let lon = dict["longitude"] as? Double else { return nil }
            return LocationPoint(latitude: lat, longitude: lon)
        }()

        let photoURLs: [String]? = {
            if let arr = data["photoURLs"] as? [String] { return arr }
            return nil
        }()

        return AppUser(
            uid: uid,
            spotifyId: stringValue("spotifyId") ?? "",
            displayName: stringValue("displayName") ?? "Unknown",
            avatarURL: stringValue("avatarURL"),
            avatarSource: stringValue("avatarSource").flatMap(AvatarSource.init(rawValue:)) ?? .unknown,
            age: intValue("age"),
            hometown: stringValue("hometown"),
            musicTaste: stringValue("musicTaste"),
            countryCode: stringValue("countryCode"),
            gender: stringValue("gender"),
            photoURLs: photoURLs,
            isBroadcasting: boolValue("isBroadcasting"),
            profileCompleted: boolValue("profileCompleted"),
            createdAt: ts("createdAt"),
            updatedAt: ts("updatedAt"),
            lastActiveAt: ts("lastActiveAt"),
            lastLocation: lastLocation
        )
    }
}

