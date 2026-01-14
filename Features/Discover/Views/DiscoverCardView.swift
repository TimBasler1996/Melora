import SwiftUI

struct DiscoverCardView: View {
    let broadcast: DiscoverBroadcast
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                cardBackground

                VStack(alignment: .leading, spacing: 12) {
                    Spacer()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                            .font(.system(size: 18, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        Text(broadcast.track.title)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        Text(broadcast.track.artist)
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .lineLimit(1)
                    }

                    HStack(spacing: 12) {
                        Label(broadcast.user.locationText, systemImage: "mappin.and.ellipse")
                        Label(distanceText, systemImage: "location.fill")
                    }
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.92))
                }
                .padding(18)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.black.opacity(0.35), in: Circle())
                }
                .padding(14)
            }
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
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
        .frame(height: 260)
        .frame(maxWidth: .infinity)
        .background(AppColors.tintedBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [Color.black.opacity(0.1), Color.black.opacity(0.7)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        )
        .shadow(color: Color.black.opacity(0.2), radius: 16, x: 0, y: 10)
        .clipped()
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
        return "\(distance) m"
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
