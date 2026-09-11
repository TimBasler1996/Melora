import SwiftUI

/// A rich, tappable card that previews a Spotify track.
/// Shows album artwork, track metadata, and Spotify branding.
/// Tapping opens the track in the Spotify app (falls back to web).
///
/// When created with `init(fetchingTrackId:)` the card fetches real metadata
/// (title, artist, album, artwork) from `SpotifyService`, showing a skeleton
/// while loading and a graceful fallback if the fetch fails.
struct SpotifyLinkCard: View {

    let trackId: String

    @State private var title: String
    @State private var artist: String
    @State private var album: String?
    @State private var artworkURL: URL?

    /// When true, the card resolves its own metadata from `SpotifyService`.
    private let autoFetch: Bool
    @State private var isLoading: Bool
    @State private var didFail: Bool = false

    @Environment(\.openURL) private var openURL

    // Spotify brand green
    private let spotifyGreen = Color(red: 0.12, green: 0.84, blue: 0.38)

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    // MARK: - Init

    init(trackId: String, title: String, artist: String, album: String?, artworkURL: URL?) {
        self.trackId = trackId
        _title = State(initialValue: title)
        _artist = State(initialValue: artist)
        _album = State(initialValue: album)
        _artworkURL = State(initialValue: artworkURL)
        self.autoFetch = false
        _isLoading = State(initialValue: false)
    }

    /// Renders a card that fetches its own metadata for `trackId`.
    init(fetchingTrackId trackId: String) {
        self.trackId = trackId
        _title = State(initialValue: "")
        _artist = State(initialValue: "")
        _album = State(initialValue: nil)
        _artworkURL = State(initialValue: nil)
        self.autoFetch = true
        _isLoading = State(initialValue: true)
    }

    var body: some View {
        Button(action: openInSpotify) {
            HStack(spacing: 14) {
                artwork

                VStack(alignment: .leading, spacing: 4) {
                    Text(displayTitle)
                        .font(AppFonts.body())
                        .fontWeight(.bold)
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)

                    Text(displayArtist)
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)

                    if let album, !album.isEmpty {
                        Text(album)
                            .font(AppFonts.footnote())
                            .foregroundColor(AppColors.mutedText)
                            .lineLimit(1)
                    }
                }
                .redacted(reason: isLoading ? .placeholder : [])

                Spacer(minLength: 0)

                // Spotify icon + label
                VStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(spotifyGreen)

                    Text("Spotify")
                        .font(AppFonts.caption())
                        .foregroundColor(spotifyGreen.opacity(0.8))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppColors.surfaceElevated)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(spotifyGreen.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .task { await fetchMetadataIfNeeded() }
    }

    // MARK: - Resolved display text

    private var displayTitle: String {
        if isLoading { return "Loading track" }
        if !title.isEmpty { return title }
        return "Spotify Track"
    }

    private var displayArtist: String {
        if isLoading { return "Loading artist" }
        if !artist.isEmpty { return artist }
        return "Tap to open"
    }

    // MARK: - Metadata fetch

    private func fetchMetadataIfNeeded() async {
        guard autoFetch, isLoading, !isRunningInPreview else {
            if isLoading { isLoading = false }
            return
        }

        do {
            let track = try await SpotifyService.shared.fetchTrack(id: trackId)
            title = track.title
            artist = track.artist
            album = track.album
            artworkURL = track.artworkURL
            didFail = false
        } catch {
            // Graceful fallback — keep the card tappable with generic copy.
            didFail = true
            print("❌ [SpotifyLinkCard] metadata fetch failed:", error.localizedDescription)
        }
        isLoading = false
    }

    // MARK: - Artwork

    private var artwork: some View {
        Group {
            if let url = artworkURL {
                RemoteImage(url: url, size: 56) { phase in
                    switch phase {
                    case .empty:
                        artworkPlaceholder
                            .overlay(ProgressView().tint(.white).scaleEffect(0.7))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        artworkPlaceholder
                    }
                }
            } else if isLoading {
                artworkPlaceholder
                    .overlay(ProgressView().tint(.white).scaleEffect(0.7))
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.stroke, lineWidth: 1)
        )
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.18, green: 0.18, blue: 0.25),
                    Color(red: 0.12, green: 0.12, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white.opacity(0.3))
        }
    }

    // MARK: - Action

    private func openInSpotify() {
        // Try Spotify deep link first, fall back to web
        let deepLink = URL(string: "spotify:track:\(trackId)")!
        let webLink = URL(string: "https://open.spotify.com/track/\(trackId)")!

        openURL(deepLink) { success in
            if !success {
                openURL(webLink)
            }
        }
    }
}

// MARK: - Convenience initializers

extension SpotifyLinkCard {
    /// Initialize from a Track model.
    init(track: Track) {
        self.init(
            trackId: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            artworkURL: track.artworkURL
        )
    }

    /// Initialize from a DiscoverTrack model.
    init(discoverTrack: DiscoverTrack) {
        self.init(
            trackId: discoverTrack.id,
            title: discoverTrack.title,
            artist: discoverTrack.artist,
            album: discoverTrack.album,
            artworkURL: discoverTrack.artworkURLValue
        )
    }
}
