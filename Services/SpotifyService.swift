import Foundation

// MARK: - Spotify User Profile

struct SpotifyUserProfile: Codable {
    let id: String
    let displayNameRaw: String?
    let images: [SpotifyImage]?
    let country: String?
    
    var displayName: String {
        displayNameRaw?.trimmingCharacters(in: .whitespacesAndNewlines)
        ?? "Spotify User"
    }
    
    var imageURL: URL? {
        guard let urlString = images?.first?.url else { return nil }
        return URL(string: urlString)
    }
    
    var countryCode: String? {
        country
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case displayNameRaw = "display_name"
        case images
        case country
    }
}

struct SpotifyImage: Codable {
    let url: String
    let height: Int?
    let width: Int?
}

// MARK: - Currently Playing response models

private struct SpotifyCurrentlyPlayingResponse: Codable {
    let item: SpotifyTrackItem?
}

private struct SpotifyTrackItem: Codable {
    let id: String?
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
}

private struct SpotifyArtist: Codable {
    let name: String
}

private struct SpotifyAlbum: Codable {
    let name: String?
    let images: [SpotifyImage]
}

// MARK: - SpotifyService

enum SpotifyAPIError: Error {
    case notAuthorized
    case noTrackPlaying
    case invalidResponse
}

final class SpotifyService {
    
    static let shared = SpotifyService()
    
    private init() {}
    
    private let apiBaseURL = URL(string: "https://api.spotify.com/v1")!
    
    // MARK: - Public API
    
    /// Fetches the currently playing track from Spotify and maps it to our `Track` model.
    func fetchCurrentlyPlaying() async throws -> Track {
        let accessToken = try await SpotifyAuthManager.shared.getValidAccessToken()
        let url = apiBaseURL.appendingPathComponent("me/player/currently-playing")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError.invalidResponse
        }
        
        // 204 = no content (no track currently playing)
        if http.statusCode == 204 {
            throw SpotifyAPIError.noTrackPlaying
        }
        
        guard (200..<300).contains(http.statusCode) else {
            print("❌ Spotify currently playing HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw SpotifyAPIError.invalidResponse
        }
        
        let decoded = try JSONDecoder().decode(SpotifyCurrentlyPlayingResponse.self, from: data)
        guard let item = decoded.item, let id = item.id else {
            throw SpotifyAPIError.noTrackPlaying
        }
        
        let artistName = item.artists.first?.name ?? "Unknown Artist"
        let albumName = item.album.name
        let artworkURL: URL?
        if let firstImageURL = item.album.images.first?.url {
            artworkURL = URL(string: firstImageURL)
        } else {
            artworkURL = nil
        }
        
        // Map to our domain Track model
        return Track(
            id: id,
            title: item.name,
            artist: artistName,
            album: albumName,
            artworkURL: artworkURL
        )
    }
    
    /// Fetches the Spotify user profile (/me).
    func fetchCurrentUserProfile() async throws -> SpotifyUserProfile {
        let accessToken = try await SpotifyAuthManager.shared.getValidAccessToken()
        let url = apiBaseURL.appendingPathComponent("me")
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            print("❌ Spotify /me HTTP error: \(String(data: data, encoding: .utf8) ?? "")")
            throw SpotifyAPIError.invalidResponse
        }
        
        let profile = try JSONDecoder().decode(SpotifyUserProfile.self, from: data)
        return profile
    }
}

