import Foundation
import FirebaseFirestore

struct UserProfile: Identifiable, Equatable {
    let uid: String
    var id: String { uid }

    var firstName: String
    var lastName: String
    var city: String
    var birthday: Date?
    var gender: String
    var photoURLs: [String]
    
    /// Uncropped hero photo for profile view (full size, not cropped)
    var heroPhotoURL: String?

    var spotifyId: String?
    var spotifyCountry: String?
    var countryCode: String?
    var spotifyAvatarURL: String?
    var spotifyDisplayName: String?

    var profileCompleted: Bool

    var fullName: String {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = [trimmedFirst, trimmedLast].filter { !$0.isEmpty }.joined(separator: " ")
        if !combined.isEmpty {
            return combined
        }
        return spotifyDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (spotifyDisplayName ?? "")
            : "Your Name"
    }

    var displayFirstName: String {
        let trimmed = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return spotifyDisplayName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? (spotifyDisplayName ?? "")
            : "Your Name"
    }

    var age: Int? {
        birthday?.age()
    }
    
    /// Returns the hero photo URL for large profile display
    /// Falls back to first photo, then Spotify avatar
    var displayHeroPhotoURL: String? {
        if let hero = heroPhotoURL, !hero.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return hero
        }
        return photoURLs.first ?? spotifyAvatarURL
    }
    
    /// Returns the cropped profile photo (first photo in photoURLs array)
    /// This is used for discovery cards and small avatars
    var croppedProfilePhotoURL: String? {
        photoURLs.first
    }

    func photoURL(at index: Int) -> String? {
        guard photoURLs.indices.contains(index) else { return nil }
        let url = photoURLs[index].trimmingCharacters(in: .whitespacesAndNewlines)
        return url.isEmpty ? nil : url
    }

    static func fromFirestore(uid: String, data: [String: Any]) -> UserProfile {
        func stringValue(_ key: String) -> String? { data[key] as? String }
        func boolValue(_ key: String) -> Bool { (data[key] as? Bool) ?? false }
        func dateValue(_ key: String) -> Date? {
            if let timestamp = data[key] as? Timestamp { return timestamp.dateValue() }
            return data[key] as? Date
        }

        let photoURLs = (data["photoURLs"] as? [String]) ?? []

        return UserProfile(
            uid: uid,
            firstName: stringValue("firstName") ?? "",
            lastName: stringValue("lastName") ?? "",
            city: stringValue("city") ?? "",
            birthday: dateValue("birthday"),
            gender: stringValue("gender") ?? "",
            photoURLs: photoURLs,
            heroPhotoURL: stringValue("heroPhotoURL"),
            spotifyId: stringValue("spotifyId"),
            spotifyCountry: stringValue("spotifyCountry"),
            countryCode: stringValue("countryCode"),
            spotifyAvatarURL: stringValue("spotifyAvatarURL") ?? stringValue("avatarURL"),
            spotifyDisplayName: stringValue("spotifyDisplayName") ?? stringValue("displayName"),
            profileCompleted: boolValue("profileCompleted")
        )
    }
}
