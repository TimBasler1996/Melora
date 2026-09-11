import Foundation
import FirebaseFirestore

/// A snapshot of someone's Spotify taste, stored on their user document so
/// other people can see it on the profile. Refreshed by `SpotifyTasteSync`.
struct SpotifyTaste: Codable, Equatable {

    struct Item: Codable, Equatable, Identifiable {
        let id: String
        let name: String
        /// Artist for a track, owner or track count for a playlist.
        var subtitle: String?
        var imageURL: String?
        /// Spotify web link (opens the app when installed).
        var url: String?
    }

    var topArtists: [Item] = []
    var topTracks: [Item] = []
    var playlists: [Item] = []
    var updatedAt: Date?

    var isEmpty: Bool { topArtists.isEmpty && topTracks.isEmpty && playlists.isEmpty }

    // MARK: - Firestore

    static func fromFirestore(_ any: Any?) -> SpotifyTaste? {
        guard let dict = any as? [String: Any] else { return nil }
        func items(_ key: String) -> [Item] {
            ((dict[key] as? [[String: Any]]) ?? []).compactMap { raw in
                guard let id = raw["id"] as? String, let name = raw["name"] as? String else { return nil }
                return Item(
                    id: id,
                    name: name,
                    subtitle: raw["subtitle"] as? String,
                    imageURL: raw["imageURL"] as? String,
                    url: raw["url"] as? String
                )
            }
        }
        let updatedAt = (dict["updatedAt"] as? Timestamp)?.dateValue() ?? dict["updatedAt"] as? Date
        let taste = SpotifyTaste(
            topArtists: items("topArtists"),
            topTracks: items("topTracks"),
            playlists: items("playlists"),
            updatedAt: updatedAt
        )
        return taste.isEmpty ? nil : taste
    }

    var firestoreValue: [String: Any] {
        func raw(_ list: [Item]) -> [[String: Any]] {
            list.map { item in
                var d: [String: Any] = ["id": item.id, "name": item.name]
                if let s = item.subtitle { d["subtitle"] = s }
                if let i = item.imageURL { d["imageURL"] = i }
                if let u = item.url { d["url"] = u }
                return d
            }
        }
        return [
            "topArtists": raw(topArtists),
            "topTracks": raw(topTracks),
            "playlists": raw(playlists),
            "updatedAt": FieldValue.serverTimestamp()
        ]
    }
}
