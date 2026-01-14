import SwiftUI

struct DiscoverDetailSheetView: View {
    let broadcast: DiscoverBroadcast
    let isSending: Bool
    let onLike: () -> Void
    let onSendMessage: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var messageText: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                trackHeader
                actionsSection
                profileSnapshot
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var trackHeader: some View {
        HStack(alignment: .center, spacing: 16) {
            artwork

            VStack(alignment: .leading, spacing: 6) {
                Text(broadcast.track.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)

                Text(broadcast.track.artist)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)

                if let album = broadcast.track.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(AppColors.mutedText)
                }

                if let spotifyURL = broadcast.track.spotifyURLValue {
                    Button {
                        openURL(spotifyURL)
                    } label: {
                        Label("Open in Spotify", systemImage: "arrow.up.right.square")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.primary)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                .fill(AppColors.cardBackground)
        )
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
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Button(action: onLike) {
                    Label("Like track", systemImage: "heart.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                        .background(AppColors.primary)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                }
                .disabled(isSending)

                Spacer(minLength: 0)
            }

            Text("Add message (optional)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.secondaryText)

            TextField("Say something nice…", text: $messageText, axis: .vertical)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .padding(12)
                .background(AppColors.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Button {
                let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onSendMessage(trimmed)
                messageText = ""
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Label("Send", systemImage: "paperplane.fill")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(AppColors.secondary)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(isSending)
        }
    }

    private var profileSnapshot: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Profile")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.secondaryText)

            HStack(alignment: .center, spacing: 14) {
                profileHero

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)

                    Text(broadcast.user.locationText)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.secondaryText)

                    chipRow
                }

                Spacer(minLength: 0)
            }

            if !broadcast.user.photoURLs.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(broadcast.user.photoURLs.prefix(6), id: \.self) { urlString in
                            photoChip(urlString)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                .fill(AppColors.cardBackground)
        )
    }

    private var profileHero: some View {
        ZStack {
            if let url = broadcast.user.primaryPhotoURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        heroPlaceholder
                    case .success(let image):
                        image.resizable().scaledToFill()
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
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary.opacity(0.6), AppColors.secondary.opacity(0.6)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 30, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))
        }
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            if let gender = broadcast.user.gender, !gender.isEmpty {
                chip(text: gender)
            }
            if let countryCode = broadcast.user.countryCode, !countryCode.isEmpty {
                chip(text: countryCode)
            }
        }
    }

    private func chip(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(AppColors.primary.opacity(0.12))
            .foregroundColor(AppColors.primary)
            .clipShape(Capsule())
    }

    private func photoChip(_ urlString: String) -> some View {
        ZStack {
            if let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Color.black.opacity(0.1)
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        Color.black.opacity(0.1)
                    @unknown default:
                        Color.black.opacity(0.1)
                    }
                }
            } else {
                Color.black.opacity(0.1)
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

#Preview {
    DiscoverDetailSheetView(
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
                photoURLs: ["https://example.com/one", "https://example.com/two"]
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
            location: nil,
            distanceMeters: 120
        ),
        isSending: false,
        onLike: {},
        onSendMessage: { _ in }
    )
}
