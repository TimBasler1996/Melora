import SwiftUI

struct TrackLikesDetailView: View {

    let user: AppUser
    let track: Track
    let likes: [TrackLike]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    header

                    trackCard

                    likesSection
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Track Likes")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("liked this track")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
            }

            Spacer()
        }
    }

    private var avatar: some View {
        Group {
            if let urlString = user.photoURLs?.first ?? user.avatarURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(Color.white.opacity(0.2))
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initials
                    @unknown default:
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var initials: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.25))
            Text(user.initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
    }

    // MARK: - Track Card

    private var trackCard: some View {
        VStack(alignment: .leading, spacing: 10) {

            Text("Track")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            HStack(spacing: 12) {
                artwork

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text(track.artist)
                        .font(AppFonts.footnote())
                        .foregroundColor(.white.opacity(0.85))

                    if let album = track.album, !album.isEmpty {
                        Text(album)
                            .font(AppFonts.footnote())
                            .foregroundColor(.white.opacity(0.65))
                    }
                }

                Spacer()
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
    }

    private var artwork: some View {
        Group {
            if let urlString = track.artworkURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholderArtwork
                    @unknown default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.white.opacity(0.25))
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(.white.opacity(0.85))
            )
    }

    // MARK: - Likes

    private var likesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("People who liked this")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            if likes.isEmpty {
                Text("No likes yet.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
            } else {
                ForEach(likes) { like in
                    HStack {
                        Text(like.displayName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)

                        Spacer()

                        Text(like.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
    }
}

