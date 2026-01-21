import SwiftUI

/// Improved TrackLikesDetailView with better UI/UX
/// Shows all likes for a track with user details, messages, and accept/ignore actions
struct TrackLikesDetailView_Improved: View {

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
            // Dark gradient background
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
                VStack(alignment: .leading, spacing: 24) {
                    trackCard
                    likesSection

                    if let toast {
                        Text(toast)
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .background(
                                Capsule()
                                    .fill(Color.white.opacity(0.15))
                            )
                            .transition(.opacity.combined(with: .scale))
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

    // MARK: - Track Card

    private var trackCard: some View {
        HStack(spacing: 16) {
            artwork

            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)

                Text(track.artist)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                if let album = track.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }
            
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }

    private var artwork: some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
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
        .frame(width: 80, height: 80)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.25, blue: 0.35),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Likes Section

    private var likesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("People who liked this")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                // Like count badge
                Text("\(pendingLikes.count)")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 32, minHeight: 32)
                    .background(
                        Circle()
                            .fill(Color.orange.opacity(0.3))
                    )
            }

            if pendingLikes.isEmpty && acceptedLikes.isEmpty {
                emptyState
            } else {
                VStack(spacing: 16) {
                    // Show pending likes first
                    ForEach(pendingLikes) { like in
                        ModernLikeRow(
                            receiverUserId: user.uid,
                            like: like,
                            isUpdating: isUpdatingIds.contains(like.id),
                            onAccept: { Task { await accept(like: like) } },
                            onReject: { Task { await update(like: like, status: .rejected) } }
                        )
                    }
                    
                    // Then accepted likes
                    ForEach(acceptedLikes) { like in
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
    
    private var pendingLikes: [TrackLike] {
        localLikes.filter { ($0.status ?? .pending) == .pending }
    }
    
    private var acceptedLikes: [TrackLike] {
        localLikes.filter { ($0.status ?? .pending) == .accepted }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "heart.slash")
                .font(.system(size: 48, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No likes yet")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Actions

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
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { 
            toast = text 
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeOut(duration: 0.2)) { 
                toast = nil 
            }
        }
    }
}

// MARK: - Modern Like Row

private struct ModernLikeRow: View {

    let receiverUserId: String
    let like: TrackLike
    let isUpdating: Bool
    let onAccept: () -> Void
    let onReject: () -> Void

    private var convoId: String {
        ChatApiService.shared.conversationId(for: receiverUserId, and: like.fromUserId)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            
            // User info header
            HStack(spacing: 12) {
                NavigationLink {
                    UserProfileDetailView(userId: like.fromUserId)
                } label: {
                    HStack(spacing: 12) {
                        avatar
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text(like.fromUserDisplayName ?? "Unknown")
                                .font(.system(size: 16, weight: .semibold, design: .rounded))
                                .foregroundColor(.white)
                            
                            Text(like.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                statusPill
            }
            
            // Message content (if exists)
            if let msg = like.message?.trimmingCharacters(in: .whitespacesAndNewlines),
               !msg.isEmpty {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                        .padding(.top, 2)
                    
                    Text("\"\(msg)\"")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.95))
                        .lineLimit(6)
                }
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.06))
                )
            }
            
            // Action buttons based on status
            actionButtons
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        switch (like.status ?? .pending) {
        case .pending:
            HStack(spacing: 12) {
                Button(action: onReject) {
                    HStack(spacing: 8) {
                        if isUpdating { 
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("Ignore")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white.opacity(0.85))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isUpdating)
                
                Button(action: onAccept) {
                    HStack(spacing: 8) {
                        if isUpdating { 
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .bold))
                        }
                        Text("Accept")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        LinearGradient(
                            colors: [
                                Color(red: 0.2, green: 0.85, blue: 0.4),
                                Color(red: 0.15, green: 0.75, blue: 0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isUpdating)
            }
            
        case .accepted:
            NavigationLink {
                ChatView(conversationId: convoId)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Open Chat")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.12))
                )
            }
            .buttonStyle(.plain)
            
        case .rejected:
            EmptyView()
        }
    }
    
    private var avatar: some View {
        Group {
            if let s = like.fromUserAvatarURL, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(Color.white.opacity(0.15))
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
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }
            } else {
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white.opacity(0.5))
                    )
            }
        }
        .frame(width: 52, height: 52)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 2)
        )
    }
    
    private var statusPill: some View {
        let s = like.status ?? .pending
        let (text, bgColor, fgColor): (String, Color, Color) = {
            switch s {
            case .pending: 
                return ("PENDING", Color.orange.opacity(0.2), Color.orange)
            case .accepted: 
                return ("ACCEPTED", Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.2), Color(red: 0.2, green: 0.85, blue: 0.4))
            case .rejected: 
                return ("IGNORED", Color.white.opacity(0.1), Color.white.opacity(0.5))
            }
        }()
        
        return Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(fgColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(bgColor)
            )
    }
}
