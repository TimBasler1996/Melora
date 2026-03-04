import SwiftUI

/// A rich, tappable card that previews a Spotify track.
/// Shows album artwork, track metadata, and Spotify branding.
/// Tapping opens the track in the Spotify app (falls back to web).
struct SpotifyLinkCard: View {

    let trackId: String
    let title: String
    let artist: String
    let album: String?
    let artworkURL: URL?

    @Environment(\.openURL) private var openURL

    // Spotify brand green
    private let spotifyGreen = Color(red: 0.12, green: 0.84, blue: 0.38)

    var body: some View {
        Button(action: openInSpotify) {
            HStack(spacing: 14) {
                artwork

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 15, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(artist)
                        .font(.system(size: 13, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    if let album, !album.isEmpty {
                        Text(album)
                            .font(.system(size: 12, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)

                // Spotify icon + "PLAY ON SPOTIFY" label
                VStack(spacing: 4) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32, weight: .medium))
                        .foregroundColor(spotifyGreen)

                    Text("Spotify")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundColor(spotifyGreen.opacity(0.8))
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(spotifyGreen.opacity(0.25), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Artwork

    private var artwork: some View {
        Group {
            if let url = artworkURL {
                AsyncImage(url: url) { phase in
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
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
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
        self.trackId = track.id
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.artworkURL = track.artworkURL
    }

    /// Initialize from a DiscoverTrack model.
    init(discoverTrack: DiscoverTrack) {
        self.trackId = discoverTrack.id
        self.title = discoverTrack.title
        self.artist = discoverTrack.artist
        self.album = discoverTrack.album
        self.artworkURL = discoverTrack.artworkURLValue
    }
}
