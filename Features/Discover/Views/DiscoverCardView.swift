import SwiftUI

struct DiscoverCardView: View {
    let broadcast: DiscoverBroadcast
    let onTap: () -> Void
    let onDismiss: () -> Void

    private let cardHeight: CGFloat = 240

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {

                VStack(spacing: 0) {
                    trackModule
                    moduleDivider
                    profileModule
                }
                .frame(height: cardHeight)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)

                dismissButton
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Modules

    /// Top: Spotify-style row (like your screenshot)
    private var trackModule: some View {
        HStack(spacing: 14) {
            trackArtworkThumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(trackTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(trackArtist)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                if let album = trackAlbum {
                    Text(album)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            spotifyPill
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Bottom: Profile row in same style (no hero crop)
    private var profileModule: some View {
        HStack(spacing: 14) {
            heroThumbnailNoCrop

            VStack(alignment: .leading, spacing: 6) {
                Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("\(broadcast.user.locationText) · \(distanceText)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                if let badgeText = badgeText {
                    profileChip(text: badgeText)
                }
            }

            Spacer(minLength: 0)

            // Subtle “tap hint” like dating apps
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var moduleDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - Track UI

    private var trackArtworkThumbnail: some View {
        ZStack {
            if let url = broadcast.track.artworkURLValue {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        artworkPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transaction { $0.animation = nil }
                    case .failure:
                        artworkPlaceholder
                    @unknown default:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    private var spotifyPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 12, weight: .semibold))
            Text("Spotify")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Profile UI (NO CROP HERO)

    /// Hero thumbnail where the image is NOT cropped:
    /// - Use scaledToFit inside a fixed frame
    /// - Provide a subtle background so letterboxing looks intentional
    private var heroThumbnailNoCrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))

            if let url = broadcast.user.primaryPhotoURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        heroPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit() // IMPORTANT: no crop
                            .padding(6)     // keeps it clean inside frame
                            .transaction { $0.animation = nil }
                    case .failure:
                        heroPlaceholder
                    @unknown default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(8)
    }

    private func profileChip(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.2))
            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
            .clipShape(Capsule())
    }

    // MARK: - Dismiss

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.60), in: Circle())
        }
        .padding(14)
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
    }

    // MARK: - Helpers

    private var distanceText: String {
        guard let distance = broadcast.distanceMeters else { return "—" }
        return "\(distance)m"
    }

    private var badgeText: String? {
        if let gender = broadcast.user.gender?.trimmingCharacters(in: .whitespacesAndNewlines),
           !gender.isEmpty {
            return gender
        }
        if let country = broadcast.user.countryCode?.trimmingCharacters(in: .whitespacesAndNewlines),
           !country.isEmpty {
            return country.uppercased()
        }
        return nil
    }

    private var trackTitle: String {
        let t = broadcast.track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Unknown track" : t
    }

    private var trackArtist: String {
        let a = broadcast.track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? "Unknown artist" : a
    }

    private var trackAlbum: String? {
        guard let raw = broadcast.track.album?.trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else { return nil }
        return raw
    }
}

