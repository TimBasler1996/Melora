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
            VStack(alignment: .leading, spacing: 18) {
                trackHeader
                actionsSection

                profileSection // ✅ shared ProfilePreviewView compact
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Track header

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

                if let album = broadcast.track.album?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !album.isEmpty {
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
                        image.resizable().scaledToFill()
                            .transaction { t in t.animation = nil }
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
        .clipped()
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

    // MARK: - Actions

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

    // MARK: - Profile (shared component)

    private var profileSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Profile")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.secondaryText)

            ProfilePreviewView(
                model: profilePreviewModelFromDiscoverUser(broadcast.user),
                density: .compact
            )
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                .fill(AppColors.cardBackground)
        )
    }

    private func profilePreviewModelFromDiscoverUser(_ u: DiscoverUser) -> ProfilePreviewModel {
        let displayName = u.displayName.trimmingCharacters(in: .whitespacesAndNewlines)

        // hero
        let hero = u.primaryPhotoURL

        // ✅ additional photos (under each other, fixed size)
        let additional = u.photoURLs
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { $0 != (hero ?? "") } // avoid duplicate hero

        func clean(_ value: String?) -> String? {
            guard let value else { return nil }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }

        return ProfilePreviewModel(
            firstName: displayName.isEmpty ? "User" : displayName,
            age: u.age,
            city: clean(u.city),
            gender: clean(u.gender),
            countryCode: clean(u.countryCode),
            heroPhotoURL: hero,
            photoURLs: additional,
            spotifyIdOrURL: nil
        )
    }
}
