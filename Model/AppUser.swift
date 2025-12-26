import Foundation

struct AppUser: Identifiable, Codable, Equatable {

    enum AvatarSource: String, Codable {
        case spotify
        case uploaded
        case none
    }

    // MARK: - Core

    let id: String              // ✅ Firestore doc id = Firebase UID
    let spotifyId: String
    var displayName: String

    // MARK: - Profile

    var age: Int?
    var hometown: String?
    var musicTaste: String?
    var photoURLs: [String]?

    var avatarURL: String?
    var avatarSource: AvatarSource?

    var profileCompleted: Bool?

    // MARK: - Presence / Discover

    var isBroadcasting: Bool?
    var lastLocation: LocationPoint?
    var lastActiveAt: Date?

    // MARK: - Timestamps

    var createdAt: Date?
    var updatedAt: Date?

    // MARK: - Helpers

    var initials: String {
        let comps = displayName.split(separator: " ")
        let first = comps.first?.first.map(String.init) ?? ""
        let second = comps.dropFirst().first?.first.map(String.init) ?? ""
        let out = (first + second).uppercased()
        return out.isEmpty ? "?" : out
    }

    var isCompleteDerived: Bool {
        let hasAge = (age ?? 0) > 0
        let hasTown = !(hometown ?? "").isEmpty
        let hasTaste = !(musicTaste ?? "").isEmpty
        let hasPhotos = (photoURLs?.isEmpty == false)
        return hasAge && hasTown && hasTaste && hasPhotos
    }
}

