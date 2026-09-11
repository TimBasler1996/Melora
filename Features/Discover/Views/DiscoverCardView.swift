import SwiftUI

/// Compact, expandable Discover Card matching the design:
/// - Collapsed: User photo (left) · Name / Track · Artist / Distance · Album art (right) · Chevron
/// - Expanded: + divider + 5 action buttons (Like, Message, Spotify, Profile, X)
struct DiscoverCardView: View {
    let broadcast: DiscoverBroadcast
    @Binding var isExpanded: Bool
    let onDismiss: () -> Void
    let onLikeTrack: () -> Void
    let onMessage: (String) -> Void
    let onViewProfile: () -> Void
    let onToggleFollow: () -> Void
    /// Opens the conversation once a message has been sent.
    var onOpenChat: () -> Void = {}

    var hasLiked: Bool = false
    var hasMessaged: Bool = false
    var isFollowing: Bool = false

    @Environment(\.openURL) private var openURL

    @State private var showHeartAnimation: Bool = false
    @State private var likeBurst: Int = 0
    @State private var glow: Color?
    @State private var showMessageField: Bool = false
    @State private var messageText: String = ""
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Card header — tap to expand/collapse
                Button {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                        if !isExpanded {
                            showMessageField = false
                        }
                    }
                } label: {
                    cardHeader
                }
                .buttonStyle(.plain)

                // Expanded: divider + actions
                if isExpanded {
                    dividerLine

                    actionButtonsRow
                        .transition(.move(edge: .top).combined(with: .opacity))

                    // Spotify Link Card — rich track preview
                    SpotifyLinkCard(discoverTrack: broadcast.track)
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))

                    if showMessageField {
                        messageInputField
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                        .fill(AppColors.cardBackground)
                    // The cover tints the card: a soft glow from the top-right.
                    if let glow {
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                            .fill(
                                RadialGradient(
                                    colors: [glow.opacity(0.55), glow.opacity(0.0)],
                                    center: .topTrailing,
                                    startRadius: 0,
                                    endRadius: 320
                                )
                            )
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                    .stroke(AppColors.stroke, lineWidth: 1)
            )
            .task(id: broadcast.track.artworkURL) {
                guard let urlString = broadcast.track.artworkURL, let url = URL(string: urlString) else {
                    glow = nil
                    return
                }
                glow = await ArtworkColorCache.shared.color(for: url)
            }

            // Heart animation overlay
            if showHeartAnimation {
                heartAnimationOverlay
            }
        }
        .onChange(of: isExpanded) { _, newValue in
            if !newValue {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    showMessageField = false
                }
            }
        }
    }

    // MARK: - Card Header

    private var cardHeader: some View {
        HStack(spacing: 12) {
            // User photo (circle) on the LEFT
            userPhoto

            // Center: Name, Track · Artist, Distance
            VStack(alignment: .leading, spacing: 3) {
                Text(broadcast.user.displayName)
                    .font(.system(size: 16, weight: .heavy))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                // The song gets the serif; that is the app's signature.
                Text(trackTitle)
                    .font(AppFonts.song(size: 21))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                Text(trackArtist)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if broadcast.isLive {
                        RippleMark(size: 12, rings: 1)
                        Text("Live")
                            .fontWeight(.bold)
                            .foregroundColor(AppColors.live)
                    } else {
                        Text("Live \(broadcast.lastSeenText)")
                            .foregroundColor(.white.opacity(0.5))
                    }
                    if let distance = broadcast.distanceMeters {
                        Text("· \(Self.formatDistance(distance))")
                            .foregroundColor(.white.opacity(0.5))
                    }
                }
                .font(.system(size: 12, weight: .medium))
            }

            Spacer(minLength: 0)

            // Album artwork (square) on the RIGHT
            albumArtwork

            // Chevron
            MIcon(isExpanded ? "chev-up" : "chev-down", size: 16, color: AppColors.mutedText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Divider

    private var dividerLine: some View {
        Rectangle()
            .fill(AppColors.surfaceElevated)
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - Action Buttons (Like, Message, Follow, Profile, X) + Spotify Link Card

    private var actionButtonsRow: some View {
        HStack(spacing: 0) {
            // 1. Like — state comes from the view model so a failed like
            // rolls the heart back instead of leaving it red.
            actionButton(
                icon: hasLiked ? "heart-fill" : "heart",
                label: hasLiked ? "Liked" : "Like",
                color: hasLiked ? AppColors.live : AppColors.primaryText
            ) {
                handleLikeAction()
            }

            // 2. Message → after sending, becomes "Open chat".
            actionButton(
                icon: "send",
                label: hasMessaged ? "Open chat" : "Message",
                color: hasMessaged ? AppColors.live : AppColors.primaryText
            ) {
                handleMessageAction()
            }

            // 3. Follow
            actionButton(
                icon: isFollowing ? "person-check" : "person-plus",
                label: isFollowing ? "Following" : "Follow",
                color: isFollowing ? AppColors.live : AppColors.primaryText
            ) {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                onToggleFollow()
            }

            // 4. Profile
            actionButton(
                icon: "person",
                label: "Profile",
                color: AppColors.primaryText
            ) {
                onViewProfile()
            }

            // 5. Dismiss (X)
            actionButton(
                icon: "x",
                label: "",
                accessibilityLabel: "Not interested",
                color: AppColors.mutedText
            ) {
                onDismiss()
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
    }

    private func actionButton(
        icon: String,
        label: String,
        accessibilityLabel: String? = nil,
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                MIcon(icon, size: 22, color: color)

                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(color.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel ?? label)
    }

    // MARK: - Message Input

    private var messageInputField: some View {
        HStack(spacing: 10) {
            TextField("Send a message...", text: $messageText, axis: .vertical)
                .focused($isMessageFieldFocused)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.stroke, lineWidth: 1)
                )
                .lineLimit(1...3)

            Button(action: handleSendMessage) {
                let empty = messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                MIcon("send", size: 18, color: AppColors.background)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(empty ? AppColors.mutedText : AppColors.live))
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMessageFieldFocused = true
            }
        }
    }

    // MARK: - Actions

    private func handleLikeAction() {
        guard !hasLiked else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        showHeartAnimation = true
        likeBurst += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showHeartAnimation = false
        }

        onLikeTrack()
    }

    private func handleMessageAction() {
        if hasMessaged {
            onOpenChat()
            return
        }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            showMessageField.toggle()
        }
    }

    private func handleSendMessage() {
        let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        onMessage(trimmed)

        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            showMessageField = false
        }
        messageText = ""
    }

    // MARK: - User Photo (circle, left side)

    private var userPhoto: some View {
        ZStack {
            if let urlString = broadcast.user.primaryPhotoURL,
               let url = URL(string: urlString) {
                RemoteImage(url: url, size: 50) { phase in
                    switch phase {
                    case .empty:
                        userPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transaction { $0.animation = nil }
                    case .failure:
                        userPlaceholder
                    }
                }
            } else {
                userPlaceholder
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(AppColors.stroke, lineWidth: 1.5)
        )
    }

    private var userPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.25, green: 0.25, blue: 0.35),
                    Color(red: 0.15, green: 0.15, blue: 0.25)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Album Artwork (square, right side)

    private var albumArtwork: some View {
        ZStack {
            if let url = broadcast.track.artworkURLValue {
                RemoteImage(url: url, size: 50) { phase in
                    switch phase {
                    case .empty:
                        artworkPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                            .transaction { $0.animation = nil }
                    case .failure:
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(AppColors.stroke, lineWidth: 1)
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
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - Heart Animation Overlay

    /// A like sends a signal: the ripple leaves the card once.
    private var heartAnimationOverlay: some View {
        RippleBurst(size: 160, trigger: likeBurst)
    }

    // MARK: - Helpers

    private var trackTitle: String {
        let t = broadcast.track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Unknown track" : t
    }

    private var trackArtist: String {
        let a = broadcast.track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? "Unknown artist" : a
    }

    /// Distance bands, never exact meters: positions are fuzzed to a ~275 m
    /// grid before they are shared, and a band is all anyone needs.
    static func formatDistance(_ meters: Int) -> String {
        if meters < 500 { return "under 500 m" }
        if meters < 1000 { return "under 1 km" }
        let km = Double(meters) / 1000.0
        if km < 10 {
            let half = (km * 2).rounded() / 2
            return half == half.rounded() ? "about \(Int(half)) km" : String(format: "about %.1f km", half)
        }
        return "about \(Int(km.rounded())) km"
    }
}
