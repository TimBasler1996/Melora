import Foundation

// MARK: - Spotify User Profile

struct SpotifyUserProfile: Codable {
    let id: String
    let displayNameRaw: String?
    let images: [SpotifyImage]?
    let country: String?

    var displayName: String {
        displayNameRaw?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Spotify User"
    }

    var imageURL: URL? {
        guard let urlString = images?.first?.url else { return nil }
        return URL(string: urlString)
    }

    var countryCode: String? { country }

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

// MARK: - Now Playing Models

private struct SpotifyCurrentlyPlayingResponse: Codable {
    let item: SpotifyTrackItem?
    let isPlaying: Bool?
    let progressMs: Int?

    enum CodingKeys: String, CodingKey {
        case item
        case isPlaying = "is_playing"
        case progressMs = "progress_ms"
    }
}

private struct SpotifyTrackItem: Codable {
    let id: String?
    let name: String
    let artists: [SpotifyArtist]
    let album: SpotifyAlbum
    let durationMs: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case artists
        case album
        case durationMs = "duration_ms"
    }
}

private struct SpotifyArtist: Codable {
    let name: String
}

private struct SpotifyAlbum: Codable {
    let name: String?
    let images: [SpotifyImage]
}

// MARK: - Errors + State

enum SpotifyAPIError: Error {
    case notAuthorized
    case noTrackPlaying
    case invalidResponse
    case noActiveDevice
}

struct NowPlayingState: Equatable {
    let track: Track?
    let isPlaying: Bool
    let progressMs: Int?
}

// MARK: - SpotifyService

final class SpotifyService {

    static let shared = SpotifyService()
    private init() {}

    private let apiBaseURL = URL(string: "https://api.spotify.com/v1")!

    // MARK: - Now Playing

    /// Fetches full now-playing state (track + isPlaying).
    func fetchNowPlayingState() async throws -> NowPlayingState {
        let accessToken = try await SpotifyAuthManager.shared.getValidAccessToken()
        let url = apiBaseURL.appendingPathComponent("me/player/currently-playing")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError.invalidResponse
        }

        // 204 = No Content (no active device OR nothing playing)
        if http.statusCode == 204 {
            return NowPlayingState(track: nil, isPlaying: false, progressMs: nil)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            print("❌ Spotify now playing HTTP \(http.statusCode): \(body)")
            if http.statusCode == 404 {
                throw SpotifyAPIError.noActiveDevice
            }
            throw SpotifyAPIError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(SpotifyCurrentlyPlayingResponse.self, from: data)

        let isPlaying = decoded.isPlaying ?? false
        let progress = decoded.progressMs

        guard let item = decoded.item else {
            return NowPlayingState(track: nil, isPlaying: false, progressMs: progress)
        }

        let safeId = item.id ?? "unknown-\(item.name)" // ads/podcast/local files may have nil id
        let artistName = item.artists.first?.name ?? "Unknown Artist"
        let albumName = item.album.name

        let artworkURL: URL? = {
            guard let firstImageURL = item.album.images.first?.url else { return nil }
            return URL(string: firstImageURL)
        }()

        let track = Track(
            id: safeId,
            title: item.name,
            artist: artistName,
            album: albumName,
            artworkURL: artworkURL,
            durationMs: item.durationMs
        )

        return NowPlayingState(track: track, isPlaying: isPlaying, progressMs: progress)
    }

    /// Backwards compatible helper.
    func fetchCurrentlyPlaying() async throws -> Track {
        let state = try await fetchNowPlayingState()
        guard let track = state.track else {
            throw SpotifyAPIError.noTrackPlaying
        }
        return track
    }

    // MARK: - Profile

    /// Fetches the Spotify user profile (/me).
    func fetchCurrentUserProfile() async throws -> SpotifyUserProfile {
        let accessToken = try await SpotifyAuthManager.shared.getValidAccessToken()
        let url = apiBaseURL.appendingPathComponent("me")

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            print("❌ Spotify /me HTTP \(http.statusCode): \(String(data: data, encoding: .utf8) ?? "")")
            throw SpotifyAPIError.invalidResponse
        }

        return try JSONDecoder().decode(SpotifyUserProfile.self, from: data)
    }

    // MARK: - Player Controls

    func play() async throws {
        try await sendPlayerCommand(path: "me/player/play", method: "PUT")
    }

    func pause() async throws {
        try await sendPlayerCommand(path: "me/player/pause", method: "PUT")
    }

    func next() async throws {
        try await sendPlayerCommand(path: "me/player/next", method: "POST")
    }

    func previous() async throws {
        try await sendPlayerCommand(path: "me/player/previous", method: "POST")
    }

    private func sendPlayerCommand(path: String, method: String) async throws {
        let accessToken = try await SpotifyAuthManager.shared.getValidAccessToken()
        let url = apiBaseURL.appendingPathComponent(path)

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw SpotifyAPIError.invalidResponse
        }

        // Spotify often returns 204 on success
        if (200..<300).contains(http.statusCode) || http.statusCode == 204 {
            return
        }

        if http.statusCode == 404 {
            throw SpotifyAPIError.noActiveDevice
        }

        throw SpotifyAPIError.invalidResponse
    }
}

