import SwiftUI

/// ✨ Final optimized TrackLikesDetailView
/// - Shows all likes for a track with full user details, messages, and smart actions
/// - Groups likes by status (pending first, accepted second, rejected hidden)
/// - Beautiful modern UI with smooth animations
/// - Handles multiple likes per track cleanly
struct TrackLikesDetailView_Final: View {

    let user: AppUser
    let track: Track
    let likes: [TrackLike]

    @State private var localLikes: [TrackLike]
    @State private var isUpdatingIds: Set<String> = []
    @State private var toast: ToastMessage?
    @State private var expandedMessageIds: Set<String> = []

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
                    Color(red: 0.12, green: 0.12, blue: 0.18),
                    Color.black.opacity(0.96)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    trackCard
                    
                    statsBar
                    
                    if !pendingLikes.isEmpty {
                        likesSection(
                            title: "New Likes",
                            likes: pendingLikes,
                            iconName: "heart.circle.fill",
                            accentColor: .orange
                        )
                    }
                    
                    if !acceptedLikes.isEmpty {
                        likesSection(
                            title: "Accepted",
                            likes: acceptedLikes,
                            iconName: "checkmark.circle.fill",
                            accentColor: Color(red: 0.2, green: 0.85, blue: 0.4)
                        )
                    }
                    
                    if pendingLikes.isEmpty && acceptedLikes.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            
            // Toast overlay
            if let toast {
                VStack {
                    Spacer()
                    ToastView(message: toast)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
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
                    .font(.system(size: 19, weight: .bold, design: .rounded))
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
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.1),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
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
        .frame(width: 88, height: 88)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.3), radius: 8, x: 0, y: 4)
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
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    // MARK: - Stats Bar
    
    private var statsBar: some View {
        HStack(spacing: 16) {
            statBadge(
                count: pendingLikes.count,
                label: "Pending",
                color: .orange
            )
            
            statBadge(
                count: acceptedLikes.count,
                label: "Accepted",
                color: Color(red: 0.2, green: 0.85, blue: 0.4)
            )
            
            Spacer()
            
            statBadge(
                count: localLikes.count,
                label: "Total",
                color: .white.opacity(0.6)
            )
        }
    }
    
    private func statBadge(count: Int, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(color)
            
            Text(label)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - Likes Section

    private func likesSection(
        title: String,
        likes: [TrackLike],
        iconName: String,
        accentColor: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(accentColor)
                
                Text(title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("\(likes.count)")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(minWidth: 28, minHeight: 28)
                    .background(
                        Circle()
                            .fill(accentColor.opacity(0.25))
                    )
            }

            VStack(spacing: 12) {
                ForEach(likes) { like in
                    ModernLikeRow(
                        receiverUserId: user.uid,
                        like: like,
                        isExpanded: expandedMessageIds.contains(like.id),
                        isUpdating: isUpdatingIds.contains(like.id),
                        onToggleExpand: {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                                if expandedMessageIds.contains(like.id) {
                                    expandedMessageIds.remove(like.id)
                                } else {
                                    expandedMessageIds.insert(like.id)
                                }
                            }
                        },
                        onAccept: { Task { await accept(like: like) } },
                        onReject: { Task { await update(like: like, status: .rejected) } }
                    )
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
        VStack(spacing: 16) {
            Image(systemName: "heart.slash")
                .font(.system(size: 56, weight: .medium))
                .foregroundColor(.white.opacity(0.3))
            
            Text("No likes yet")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.7))
            
            Text("When someone likes this track, they'll appear here")
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 80)
    }

    // MARK: - Actions
    
    // Helper to get display name with fallback (used in toasts)
    private func displayName(for like: TrackLike) -> String {
        if let name = like.fromUserDisplayName, !name.isEmpty {
            return name
        }
        let shortId = String(like.fromUserId.prefix(6))
        return "User \(shortId)"
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

            // Update local state
            if let idx = localLikes.firstIndex(where: { $0.id == like.id }) {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
                    localLikes[idx].status = status
                }
            }

            if status == .accepted, createChat {
                print("🟢 [Chat] creating stub for receiver=\(user.uid) liker=\(like.fromUserId) likeId=\(like.id)")
                let convo = try await ChatApiService.shared.createConversationStubIfNeeded(
                    acceptedLike: like,
                    receiverUserId: user.uid
                )
                print("✅ [Chat] stub ready convoId=\(convo.id)")
                showToast(
                    .success(
                        "Accepted! Chat created with \(displayName(for: like))"
                    )
                )
            } else if status == .accepted {
                showToast(.success("Accepted ✓"))
            } else {
                showToast(.info("Ignored"))
            }

        } catch {
            print("❌ [Like/Chat] failed:", error.localizedDescription)
            showToast(.error("Failed: \(error.localizedDescription)"))
        }
    }

    private func showToast(_ message: ToastMessage) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) { 
            toast = message 
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeOut(duration: 0.25)) { 
                toast = nil 
            }
        }
    }
}

// MARK: - Modern Like Row

private struct ModernLikeRow: View {

    let receiverUserId: String
    let like: TrackLike
    let isExpanded: Bool
    let isUpdating: Bool
    let onToggleExpand: () -> Void
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
        // Create a short fallback from userId
        let shortId = String(like.fromUserId.prefix(6))
        return "User \(shortId)"
    }
    
    private var hasMessage: Bool {
        guard let msg = like.message?.trimmingCharacters(in: .whitespacesAndNewlines) else { return false }
        return !msg.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            
            // User info header
            Button(action: onToggleExpand) {
                HStack(spacing: 12) {
                    avatar
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(displayName(for: like))
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                        
                        HStack(spacing: 6) {
                            Image(systemName: "clock.fill")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white.opacity(0.5))
                            
                            Text(like.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 13, weight: .regular, design: .rounded))
                                .foregroundColor(.white.opacity(0.6))
                        }
                        
                        if hasMessage {
                            HStack(spacing: 4) {
                                Image(systemName: "message.fill")
                                    .font(.system(size: 10, weight: .medium))
                                Text(isExpanded ? "Tap to collapse" : "Tap to read message")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                            .foregroundColor(.cyan.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        statusPill
                        
                        if hasMessage {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(16)
            }
            .buttonStyle(.plain)
            
            // Message content (expandable)
            if hasMessage, isExpanded {
                messageSection
                    .transition(.opacity.combined(with: .scale(scale: 0.95, anchor: .top)))
            }
            
            // Location (if exists)
            if let place = like.placeLabel, !place.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text(place)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.04))
            }
            
            // Action buttons
            actionButtons
                .padding(16)
        }
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.09),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 8, x: 0, y: 4)
    }
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))
            
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "quote.opening")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.cyan.opacity(0.6))
                    .padding(.top, 2)
                
                Text(like.message ?? "")
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.95))
                    .lineSpacing(4)
                
                Spacer(minLength: 0)
            }
            .padding(16)
            .background(
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(0.08),
                        Color.cyan.opacity(0.04)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        let status = like.status ?? .pending
        
        switch status {
        case .pending:
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.bottom, 16)
                
                HStack(spacing: 12) {
                    Button(action: onReject) {
                        HStack(spacing: 8) {
                            if isUpdating { 
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
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
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text("Accept & Chat")
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
                        .shadow(
                            color: Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.4), 
                            radius: 10, 
                            x: 0, 
                            y: 5
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isUpdating)
                }
            }
            
        case .accepted:
            VStack(spacing: 0) {
                Divider()
                    .background(Color.white.opacity(0.1))
                    .padding(.bottom, 16)
                
                HStack(spacing: 12) {
                    // Navigate to user profile
                    NavigationLink {
                        UserProfilePreviewView(userId: like.fromUserId)
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                            Text("View Profile")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                        }
                        .frame(maxWidth: .infinity)
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.1))
                        )
                    }
                    .buttonStyle(.plain)
                    
                    // Navigate to chat
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
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.5),
                                    Color.blue.opacity(0.5)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .shadow(color: Color.cyan.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            
        case .rejected:
            EmptyView()
        }
    }
    
    private var avatar: some View {
        Group {
            if let s = like.fromUserAvatarURL, !s.isEmpty, let url = URL(string: s) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.2),
                                        Color.white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
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
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
        )
        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
    }
    
    private var avatarPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.2),
                        Color.white.opacity(0.1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "person.fill")
                    .font(.system(size: 26, weight: .medium))
                    .foregroundColor(.white.opacity(0.5))
            )
    }
    
    private var statusPill: some View {
        let s = like.status ?? .pending
        let (text, bgColors, fgColor): (String, [Color], Color) = {
            switch s {
            case .pending: 
                return (
                    "NEW",
                    [Color.orange.opacity(0.3), Color.orange.opacity(0.2)],
                    Color.orange
                )
            case .accepted: 
                return (
                    "ACCEPTED",
                    [
                        Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.3),
                        Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.2)
                    ],
                    Color(red: 0.2, green: 0.85, blue: 0.4)
                )
            case .rejected: 
                return (
                    "IGNORED",
                    [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                    Color.white.opacity(0.5)
                )
            }
        }()
        
        return Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundColor(fgColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: bgColors,
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
    }
}

// MARK: - Toast Message

enum ToastMessage: Equatable {
    case success(String)
    case error(String)
    case info(String)
    
    var text: String {
        switch self {
        case .success(let msg), .error(let msg), .info(let msg):
            return msg
        }
    }
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var colors: [Color] {
        switch self {
        case .success: 
            return [
                Color(red: 0.2, green: 0.85, blue: 0.4),
                Color(red: 0.15, green: 0.75, blue: 0.35)
            ]
        case .error: 
            return [
                Color.red.opacity(0.8),
                Color.red.opacity(0.6)
            ]
        case .info: 
            return [
                Color.cyan.opacity(0.7),
                Color.blue.opacity(0.6)
            ]
        }
    }
}

private struct ToastView: View {
    let message: ToastMessage
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: message.icon)
                .font(.system(size: 16, weight: .semibold))
            
            Text(message.text)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .lineLimit(2)
            
            Spacer(minLength: 0)
        }
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            Capsule()
                .fill(
                    LinearGradient(
                        colors: message.colors,
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        )
        .shadow(color: message.colors[0].opacity(0.4), radius: 12, x: 0, y: 6)
    }
}
