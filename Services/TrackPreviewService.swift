import Foundation

/// Finds a ~30 s audio preview for a track.
///
/// Spotify stopped returning `preview_url` in the Web API, so the snippet
/// comes from the two public catalogues that still publish one: Apple's
/// iTunes Search API first, Deezer as the fallback. Measured on a sample of
/// the real track pool, one of the two has a match for practically every
/// song; neither needs an API key.
///
/// Results are cached per Spotify track id for the session. Deezer URLs
/// carry an expiry token, so a lookup is re-run rather than persisted.
actor TrackPreviewService {

    static let shared = TrackPreviewService()

    /// `nil` means "looked, found nothing" — cached so the UI asks once.
    private var cache: [String: URL?] = [:]
    private var inFlight: [String: Task<URL?, Never>] = [:]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// The preview for a track, or `nil` when no catalogue has one.
    func previewURL(trackId: String, title: String, artist: String) async -> URL? {
        if let cached = cache[trackId] { return cached }
        if let task = inFlight[trackId] { return await task.value }

        let task = Task<URL?, Never> { [weak self] in
            guard let self else { return nil }
            let found = await self.lookup(title: title, artist: artist)
            await self.store(trackId: trackId, url: found)
            return found
        }
        inFlight[trackId] = task
        let result = await task.value
        inFlight[trackId] = nil
        return result
    }

    private func store(trackId: String, url: URL?) {
        cache[trackId] = url
    }

    // MARK: - Lookup

    private func lookup(title: String, artist: String) async -> URL? {
        let title = Self.cleanTitle(title)
        // Collaborations list every artist; the first one carries the match.
        let artist = artist.split(separator: ",").first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? artist
        guard !title.isEmpty, !artist.isEmpty else { return nil }

        if let url = await itunesPreview(title: title, artist: artist) { return url }
        return await deezerPreview(title: title, artist: artist)
    }

    private func itunesPreview(title: String, artist: String) async -> URL? {
        var components = URLComponents(string: "https://itunes.apple.com/search")!
        components.queryItems = [
            URLQueryItem(name: "term", value: "\(title) \(artist)"),
            URLQueryItem(name: "media", value: "music"),
            URLQueryItem(name: "entity", value: "song"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let url = components.url,
              let data = try? await session.data(from: url).0,
              let root = try? JSONDecoder().decode(ITunesResponse.self, from: data)
        else { return nil }

        return root.results
            .first { Self.artistMatches(artist, $0.artistName) && $0.previewUrl != nil }
            .flatMap { $0.previewUrl.flatMap(URL.init(string:)) }
    }

    private func deezerPreview(title: String, artist: String) async -> URL? {
        var components = URLComponents(string: "https://api.deezer.com/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(title) \(artist)"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let url = components.url,
              let data = try? await session.data(from: url).0,
              let root = try? JSONDecoder().decode(DeezerResponse.self, from: data)
        else { return nil }

        return root.data
            .first { Self.artistMatches(artist, $0.artist.name) && !($0.preview ?? "").isEmpty }
            .flatMap { $0.preview.flatMap(URL.init(string:)) }
    }

    // MARK: - Matching

    /// Drops the remix/live/feat. suffix Spotify titles carry; the catalogues
    /// usually list the plain title.
    private static func cleanTitle(_ title: String) -> String {
        var cleaned = title
        if let dash = cleaned.range(of: " - ") {
            cleaned = String(cleaned[..<dash.lowerBound])
        }
        if let paren = cleaned.firstIndex(of: "(") {
            cleaned = String(cleaned[..<paren])
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Lenient on purpose: catalogues spell "&"/"and", accents and features
    /// differently, so a shared prefix of the stripped names is the signal.
    private static func artistMatches(_ wanted: String, _ candidate: String) -> Bool {
        let a = normalized(wanted), b = normalized(candidate)
        guard !a.isEmpty, !b.isEmpty else { return false }
        let probe = String(a.prefix(10))
        return b.contains(probe) || a.contains(String(b.prefix(10)))
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }

    // MARK: - Responses

    private struct ITunesResponse: Decodable {
        struct Item: Decodable {
            let artistName: String
            let previewUrl: String?
        }
        let results: [Item]
    }

    private struct DeezerResponse: Decodable {
        struct Artist: Decodable { let name: String }
        struct Item: Decodable {
            let artist: Artist
            let preview: String?
        }
        let data: [Item]
    }
}
