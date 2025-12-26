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
}

