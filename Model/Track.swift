import Foundation

struct Track: Identifiable, Codable, Equatable {
    var id: String                 // Spotify track ID
    var title: String
    var artist: String
    var album: String?
    var artworkURL: URL?
    var durationMs: Int?
    
    init(
        id: String,
        title: String,
        artist: String,
        album: String? = nil,
        artworkURL: URL? = nil,
        durationMs: Int? = nil
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.artworkURL = artworkURL
        self.durationMs = durationMs
    }
}
