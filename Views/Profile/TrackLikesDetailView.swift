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
                        receiverUserId: user.uid,
                        like: like,
                        isUpdating: isUpdatingIds.contains(like.id),
                        onAccept: { Task { await accept(like: like) } },
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

    private func accept(like: TrackLike) async {
        await update(like: like, status: .accepted, createChat: true)
    }

    private func update(like: TrackLike, status: TrackLike.Status, createChat: Bool = false) async {
        guard !isUpdatingIds.contains(like.id) else { return }
        isUpdatingIds.insert(like.id)
        defer { isUpdatingIds.remove(like.id) }

        do {
            print("🟢 [Like] update status \(status.rawValue) likeId=\(like.id)")

            try await LikeApiService.shared.setLikeStatusReceivedOnly(
                likeId: like.id,
                toUserId: user.uid,
                status: status
            )

            if let idx = localLikes.firstIndex(where: { $0.id == like.id }) {
                localLikes[idx].status = status
            }

            if status == .accepted, createChat {
                print("🟢 [Chat] creating stub for receiver=\(user.uid) liker=\(like.fromUserId) likeId=\(like.id)")
                let convo = try await ChatApiService.shared.createConversationStubIfNeeded(
                    acceptedLike: like,
                    receiverUserId: user.uid
                )
                print("✅ [Chat] stub ready convoId=\(convo.id)")
                showToast("Accepted ✅ Chat created ✅")
            } else {
                showToast(status == .accepted ? "Accepted ✅" : "Ignored ✅")
            }

        } catch {
            print("❌ [Like/Chat] failed:", error.localizedDescription)
            showToast("Failed: \(error.localizedDescription)")
        }
    }

    private func showToast(_ text: String) {
        withAnimation(.easeInOut(duration: 0.2)) { toast = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation(.easeInOut(duration: 0.2)) { toast = nil }
        }
    }
}

// MARK: - Like Row

private struct LikeRow: View {

    let receiverUserId: String
    let like: TrackLike
    let isUpdating: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    private var convoId: String {
        ChatApiService.shared.conversationId(for: receiverUserId, and: like.fromUserId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {
                NavigationLink {
                    UserProfileDetailView(userId: like.fromUserId)
                } label: {
                    HStack(spacing: 10) {
                        avatar

                        VStack(alignment: .leading, spacing: 2) {
                            Text(like.fromUserDisplayName ?? "Unknown user")
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

            if let msg = like.message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !msg.isEmpty {
                Text("“\(msg)”")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.92))
            }

            switch (like.status ?? .pending) {
            case .pending:
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

            case .accepted:
                NavigationLink {
                    ChatView(conversationId: convoId)
                } label: {
                    HStack {
                        Image(systemName: "message.fill")
                        Text("Open Chat")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)

            case .rejected:
                EmptyView()
            }
        }
    }

    private var avatar: some View {
        Group {
            if let s = like.fromUserAvatarURL, let url = URL(string: s) {
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
}

