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
            // Dark gradient background similar to NowPlayingView
            LinearGradient(
                colors: [
                    Color(red: 0.15, green: 0.15, blue: 0.2),
                    Color.black.opacity(0.95)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    trackCard
                    likesSection

                    if let toast {
                        Text(toast)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.12))
                            )
                            .transition(.opacity)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Track Likes")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                artwork

                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 18, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(2)

                    Text(track.artist)
                        .font(.system(size: 15, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)

                    if let album = track.album, !album.isEmpty {
                        Text(album)
                            .font(.system(size: 13, weight: .medium, design: .default))
                            .foregroundColor(.white.opacity(0.4))
                            .lineLimit(1)
                    }
                }

                Spacer()
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }

    private var artwork: some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                            )
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.white.opacity(0.08))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 32, weight: .thin))
                    .foregroundColor(.white.opacity(0.3))
            )
    }

    private var likesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("People who liked this")
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            if localLikes.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "heart.slash")
                        .font(.system(size: 40, weight: .light))
                        .foregroundColor(.white.opacity(0.3))
                    
                    Text("No likes yet")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 12) {
                    ForEach(localLikes) { like in
                        ModernLikeRow(
                            receiverUserId: user.uid,
                            like: like,
                            isUpdating: isUpdatingIds.contains(like.id),
                            onAccept: { Task { await accept(like: like) } },
                            onReject: { Task { await update(like: like, status: .rejected) } }
                        )
                    }
                }
            }
        }
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

private struct ModernLikeRow: View {

    let receiverUserId: String
    let like: TrackLike
    let isUpdating: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    private var convoId: String {
        ChatApiService.shared.conversationId(for: receiverUserId, and: like.fromUserId)
    }
    
    // Helper to get display name with fallback
    private func displayName(for like: TrackLike) -> String {
        if let name = like.fromUserDisplayName, !name.isEmpty {
            return name
        }
        // Create a short fallback from userId (e.g., "User abc123" -> "User abc")
        let shortId = String(like.fromUserId.prefix(6))
        return "User \(shortId)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            HStack(spacing: 10) {
                NavigationLink {
                    UserProfilePreviewView(userId: like.fromUserId)
                } label: {
                    HStack(spacing: 10) {
                        avatar

                        VStack(alignment: .leading, spacing: 2) {
                            Text(displayName(for: like))
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
                        Circle()
                            .fill(Color.white.opacity(0.12))
                            .overlay(
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.7)
                            )
                    case .success(let img):
                        img
                            .resizable()
                            .scaledToFill()
                    default:
                        avatarPlaceholder
                    }
                }
            } else {
                avatarPlaceholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color(red: 0.3, green: 0.3, blue: 0.4),
                        Color(red: 0.2, green: 0.2, blue: 0.3)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            )
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
        
        let color: Color = {
            switch s {
            case .pending: return Color.white.opacity(0.12)
            case .accepted: return Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.2)
            case .rejected: return Color.white.opacity(0.08)
            }
        }()

        return Text(text)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundColor(.white.opacity(0.7))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(color)
            )
    }
}

