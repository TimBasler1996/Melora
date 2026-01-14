import SwiftUI

struct DiscoverCardView: View {
    let broadcast: DiscoverBroadcast
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                GeometryReader { proxy in
                    let halfWidth = proxy.size.width / 2

                    HStack(spacing: 0) {
                        userSide
                            .frame(width: halfWidth)

                        divider

                        trackSide
                            .frame(width: halfWidth)
                    }
                    .frame(height: proxy.size.height)
                }
                .frame(height: 260)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
                .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 10)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.6), in: Circle())
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }

    private var userSide: some View {
        ZStack(alignment: .bottomLeading) {
            userBackground

            LinearGradient(
                colors: [Color.black.opacity(0.05), Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(broadcast.user.locationText) · \(distanceText)")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)

                if let badgeText = badgeText {
                    badge(text: badgeText)
                }
            }
            .padding(16)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
    }

    private var userBackground: some View {
        ZStack {
            if let url = broadcast.user.primaryPhotoURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        placeholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    case .failure:
                        placeholder
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .clipped()
    }

    private var trackSide: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                artwork

                VStack(alignment: .leading, spacing: 6) {
                    Text(broadcast.track.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(2)

                    Text(broadcast.track.artist)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)

                    if let album = broadcast.track.album, !album.isEmpty {
                        Text(album)
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.mutedText)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(AppColors.secondaryText)
                Text("Spotify")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
            }
            .opacity(0.7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(AppColors.cardBackground)
    }

    private var artwork: some View {
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
        .frame(width: 104, height: 104)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary.opacity(0.7), AppColors.secondary.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "music.note")
                .font(.system(size: 26, weight: .bold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var divider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1)
    }

    private var placeholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary.opacity(0.6), AppColors.secondary.opacity(0.7)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Image(systemName: "person.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))
        }
    }

    private var distanceText: String {
        guard let distance = broadcast.distanceMeters else {
            return "—"
        }
        return "\(distance)m"
    }

    private var badgeText: String? {
        if let gender = broadcast.user.gender, !gender.isEmpty {
            return gender
        }
        if let country = broadcast.user.countryCode, !country.isEmpty {
            return country
        }
        return nil
    }

    private func badge(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.18))
            .foregroundColor(.white)
            .clipShape(Capsule())
    }
}

#Preview {
    DiscoverCardView(
        broadcast: DiscoverBroadcast(
            id: "preview",
            user: DiscoverUser(
                id: "user",
                firstName: "Lina",
                lastName: "Klein",
                age: 24,
                city: "Hamburg",
                gender: "Female",
                countryCode: "DE",
                heroPhotoURL: nil,
                profilePhotoURL: nil,
                photoURLs: []
            ),
            track: DiscoverTrack(
                id: "track",
                title: "Solar Nights",
                artist: "Aurora",
                album: "Skyline",
                artworkURL: nil,
                spotifyTrackURL: nil
            ),
            broadcastedAt: Date(),
            location: LocationPoint(latitude: 53.55, longitude: 9.99),
            distanceMeters: 320
        ),
        onTap: {},
        onDismiss: {}
    )
    .padding()
    .background(AppColors.background)
}
