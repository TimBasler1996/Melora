import SwiftUI

struct TrackLikesDetailView: View {

    let user: AppUser
    let track: Track
    let likes: [TrackLike]

    @State private var localLikes: [TrackLike]
    @State private var isUpdatingIds: Set<String> = []
    @State private var toast: String?

    init(user: AppUser, track: Track, likes: [TrackLike]) {
        self.user = user
        self.track = track
        self.likes = likes
        _localLikes = State(initialValue: likes)
    }

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
                    trackHeader
                    trackCard
                    likesSection

                    if let toast {
                        Text(toast)
                            .font(AppFonts.footnote())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.white.opacity(0.14))
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 12)
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Track Likes")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var trackHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(track.title)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .lineLimit(2)

            Text(track.artist)
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.85))
                .lineLimit(1)
        }
    }

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
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
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
            .overlay(Image(systemName: "music.note").foregroundColor(.white.opacity(0.85)))
    }

    private var likesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Likes")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            if localLikes.isEmpty {
                Text("No likes yet.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
            } else {
                ForEach(localLikes) { like in
                    LikeRow(
                        like: like,
                        isUpdating: isUpdatingIds.contains(like.id),
                        onAccept: { Task { await update(like: like, status: .accepted) } },
                        onReject: { Task { await update(like: like, status: .rejected) } }
                    )
                    .padding(.vertical, 6)

                    Divider().background(Color.white.opacity(0.18))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.18))
        )
    }

    private func update(like: TrackLike, status: TrackLike.Status) async {
        guard !isUpdatingIds.contains(like.id) else { return }
        isUpdatingIds.insert(like.id)
        defer { isUpdatingIds.remove(like.id) }

        do {
            try await LikeApiService.shared.setLikeStatusReceivedOnly(
                likeId: like.id,
                toUserId: user.uid,
                status: status
            )

            if let idx = localLikes.firstIndex(where: { $0.id == like.id }) {
                localLikes[idx].status = status
            }

            withAnimation(.easeInOut(duration: 0.2)) {
                toast = (status == .accepted) ? "Accepted ✅" : "Ignored ✅"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                withAnimation(.easeInOut(duration: 0.2)) { toast = nil }
            }

        } catch {
            withAnimation(.easeInOut(duration: 0.2)) {
                toast = "Accept/Ignore failed: \(error.localizedDescription)"
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
                withAnimation(.easeInOut(duration: 0.2)) { toast = nil }
            }
        }
    }
}

// MARK: - Like Row (with live user fallback)

private struct LikeRow: View {

    let like: TrackLike
    let isUpdating: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    @State private var fetchedUser: AppUser?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {

                NavigationLink {
                    UserProfileDetailView(userId: like.fromUserId)
                } label: {
                    HStack(spacing: 10) {
                        avatar

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName)
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)

                            Text(like.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                statusPill
            }
            .onAppear { loadUserIfNeeded() }

            if let msg = like.message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !msg.isEmpty {
                Text("“\(msg)”")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.92))
            }

            if (like.status ?? .pending) == .pending {
                HStack(spacing: 10) {
                    Button(action: onReject) {
                        HStack(spacing: 8) {
                            if isUpdating { ProgressView().tint(.white) }
                            Text("Ignore")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.12))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)

                    Button(action: onAccept) {
                        HStack(spacing: 8) {
                            if isUpdating { ProgressView().tint(.white) }
                            Text("Accept")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.22))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)
                }
            }
        }
    }

    private var displayName: String {
        if let n = like.fromUserDisplayName, !n.isEmpty { return n }
        if let n = fetchedUser?.displayName, !n.isEmpty { return n }
        return "Unknown user"
    }

    private var avatarURLString: String? {
        if let u = like.fromUserAvatarURL, !u.isEmpty { return u }
        if let u = fetchedUser?.avatarURL, !u.isEmpty { return u }
        if let u = fetchedUser?.photoURLs?.first, !u.isEmpty { return u }
        return nil
    }

    private var avatar: some View {
        Group {
            if let s = avatarURLString, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(Color.white.opacity(0.18))
                            .overlay(ProgressView().tint(.white))
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        Circle().fill(Color.white.opacity(0.18))
                            .overlay(Image(systemName: "person.fill").foregroundColor(.white.opacity(0.85)))
                    }
                }
            } else {
                Circle().fill(Color.white.opacity(0.18))
                    .overlay(Image(systemName: "person.fill").foregroundColor(.white.opacity(0.85)))
            }
        }
        .frame(width: 38, height: 38)
        .clipShape(Circle())
    }

    private var statusPill: some View {
        let s = like.status ?? .pending
        let text: String = {
            switch s {
            case .pending: return "PENDING"
            case .accepted: return "ACCEPTED"
            case .rejected: return "IGNORED"
            }
        }()
        return Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.95))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.14))
            .clipShape(Capsule())
    }

    private func loadUserIfNeeded() {
        // If like already has displayName/avatar we don’t need to fetch.
        if let n = like.fromUserDisplayName, !n.isEmpty { return }
        if fetchedUser != nil { return }

        UserApiService.shared.fetchUser(uid: like.fromUserId) { result in
            switch result {
            case .success(let u):
                DispatchQueue.main.async { self.fetchedUser = u }
            case .failure:
                break
            }
        }
    }
}

