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
///
/// A transport failure is never cached as "no preview": one moment of bad
/// signal would otherwise mark a song snippet-less for the rest of the
/// session.
actor TrackPreviewService {

    static let shared = TrackPreviewService()

    /// What a lookup can come back with. `none` is a real answer and gets
    /// cached; `failed` is "ask again".
    enum Outcome: Equatable {
        case url(URL)
        case none
        case failed

        var url: URL? {
            if case .url(let url) = self { return url }
            return nil
        }
    }

    /// `nil` means "looked, found nothing" — cached so the UI asks once.
    private var cache: [String: URL?] = [:]
    private var inFlight: [String: Task<Outcome, Never>] = [:]

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        config.waitsForConnectivity = false
        return URLSession(configuration: config)
    }()

    /// The preview for a track.
    func preview(trackId: String, title: String, artist: String) async -> Outcome {
        if let cached = cache[trackId] {
            return cached.map(Outcome.url) ?? .none
        }
        if let task = inFlight[trackId] { return await task.value }

        let task = Task<Outcome, Never> { [weak self] in
            guard let self else { return .failed }
            let outcome = await self.lookup(title: title, artist: artist)
            // Only a definitive answer is worth remembering.
            if case .failed = outcome {} else {
                await self.store(trackId: trackId, url: outcome.url)
            }
            return outcome
        }
        inFlight[trackId] = task
        let result = await task.value
        inFlight[trackId] = nil
        return result
    }

    /// Forgets a cached URL, e.g. after a signed Deezer link expired.
    func invalidate(trackId: String) {
        cache.removeValue(forKey: trackId)
    }

    private func store(trackId: String, url: URL?) {
        // updateValue, not `cache[id] = url`: assigning a nil URL through the
        // subscript would remove the entry instead of caching "none exists".
        cache.updateValue(url, forKey: trackId)
    }

    // MARK: - Lookup

    private func lookup(title: String, artist: String) async -> Outcome {
        let title = Self.cleanTitle(title)
        // Collaborations list every artist; the first one carries the match.
        let artist = artist.split(separator: ",").first.map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? artist
        guard !title.isEmpty, !artist.isEmpty else { return .none }

        var reachedACatalogue = false

        switch await itunesPreview(title: title, artist: artist) {
        case .url(let url): return .url(url)
        case .none: reachedACatalogue = true
        case .failed: break
        }

        switch await deezerPreview(title: title, artist: artist) {
        case .url(let url): return .url(url)
        case .none: reachedACatalogue = true
        case .failed: break
        }

        // Neither request got through: that is "ask again", not "none exists".
        return reachedACatalogue ? .none : .failed
    }

    private func itunesPreview(title: String, artist: String) async -> Outcome {
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
        else { return .failed }

        let match = root.results
            .first { Self.artistMatches(artist, $0.artistName) && $0.previewUrl != nil }
            .flatMap { $0.previewUrl.flatMap(URL.init(string:)) }
        return match.map(Outcome.url) ?? .none
    }

    private func deezerPreview(title: String, artist: String) async -> Outcome {
        var components = URLComponents(string: "https://api.deezer.com/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "\(title) \(artist)"),
            URLQueryItem(name: "limit", value: "5"),
        ]
        guard let url = components.url,
              let data = try? await session.data(from: url).0,
              let root = try? JSONDecoder().decode(DeezerResponse.self, from: data)
        else { return .failed }

        let match = root.data
            .first { Self.artistMatches(artist, $0.artist.name) && !($0.preview ?? "").isEmpty }
            .flatMap { $0.preview.flatMap(URL.init(string:)) }
        return match.map(Outcome.url) ?? .none
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
