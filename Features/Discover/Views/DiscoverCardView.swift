import SwiftUI

/// Compact, expandable Discover Card
/// - Collapsed: album artwork + track info + user info (compact row)
/// - Expanded: reveals 4 action buttons (Like, Message, Spotify, Profile)
struct DiscoverCardView: View {
    let broadcast: DiscoverBroadcast
    let onDismiss: () -> Void
    let onLikeTrack: () -> Void
    let onMessage: (String) -> Void
    let onViewProfile: () -> Void

    var hasLiked: Bool = false
    var hasMessaged: Bool = false

    @Environment(\.openURL) private var openURL

    @State private var isExpanded: Bool = false
    @State private var isLiked: Bool = false
    @State private var showHeartAnimation: Bool = false
    @State private var showMessageField: Bool = false
    @State private var messageText: String = ""
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Compact card header (always visible) — tap to expand/collapse
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

                // Expanded section: 4 action buttons
                if isExpanded {
                    actionButtonsRow
                        .transition(.move(edge: .top).combined(with: .opacity))

                    // Message input (shown after tapping Message)
                    if showMessageField {
                        messageInputField
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)

            // Dismiss (X) button
            dismissButton

            // Heart animation overlay
            if showHeartAnimation {
                heartAnimationOverlay
            }
        }
        .onAppear {
            isLiked = hasLiked
        }
    }

    // MARK: - Card Header (compact row)

    private var cardHeader: some View {
        HStack(spacing: 14) {
            // Album artwork
            albumArtwork

            // Track + user info
            VStack(alignment: .leading, spacing: 6) {
                // Track
                VStack(alignment: .leading, spacing: 2) {
                    Text(trackTitle)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)

                    Text(trackArtist)
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }

                // User
                HStack(spacing: 8) {
                    userThumbnail

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        HStack(spacing: 4) {
                            Image(systemName: "location.fill")
                                .font(.system(size: 10))
                            Text(broadcast.user.locationText)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                            if let distance = broadcast.distanceMeters {
                                Text("· \(Self.formatDistance(distance))")
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                            }
                        }
                        .foregroundColor(.white.opacity(0.55))
                    }
                }
            }

            Spacer(minLength: 0)

            // Expand chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .padding(.trailing, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }

    // MARK: - 4 Action Buttons

    private var actionButtonsRow: some View {
        HStack(spacing: 0) {
            // 1. Like
            actionButton(
                icon: isLiked ? "heart.fill" : "heart",
                label: "Like",
                color: isLiked ? .red : .white,
                disabled: isLiked
            ) {
                handleLikeAction()
            }

            // 2. Message
            actionButton(
                icon: hasMessaged ? "paperplane.fill" : "paperplane",
                label: "Message",
                color: hasMessaged ? Color(red: 0.2, green: 0.85, blue: 0.4) : .white,
                disabled: hasMessaged
            ) {
                handleMessageAction()
            }

            // 3. Spotify
            actionButton(
                icon: "music.note",
                label: "Spotify",
                color: Color(red: 0.12, green: 0.84, blue: 0.38),
                disabled: broadcast.track.spotifyURLValue == nil
            ) {
                if let url = broadcast.track.spotifyURLValue {
                    openURL(url)
                }
            }

            // 4. Profile
            actionButton(
                icon: "person.crop.circle",
                label: "Profil",
                color: .white,
                disabled: false
            ) {
                onViewProfile()
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, showMessageField ? 4 : 14)
    }

    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        disabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(disabled && label != "Spotify" ? color.opacity(0.5) : color)

                Text(label)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(disabled && label != "Spotify" ? color.opacity(0.5) : color.opacity(0.85))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(disabled && label != "Spotify" ? true : false)
    }

    // MARK: - Message Input

    private var messageInputField: some View {
        HStack(spacing: 10) {
            TextField("Send a message...", text: $messageText, axis: .vertical)
                .focused($isMessageFieldFocused)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .lineLimit(1...3)

            Button(action: handleSendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(
                        messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? .white.opacity(0.25)
                            : Color(red: 0.2, green: 0.85, blue: 0.4)
                    )
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMessageFieldFocused = true
            }
        }
    }

    // MARK: - Actions

    private func handleLikeAction() {
        guard !isLiked else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked = true
            showHeartAnimation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                showHeartAnimation = false
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            showHeartAnimation = false
        }

        onLikeTrack()
    }

    private func handleMessageAction() {
        guard !hasMessaged else { return }
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

    // MARK: - Album Artwork (compact)

    private var albumArtwork: some View {
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
                            .transaction { $0.animation = nil }
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
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
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
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - User Thumbnail (small circle)

    private var userThumbnail: some View {
        ZStack {
            if let urlString = broadcast.user.primaryPhotoURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
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
                    @unknown default:
                        userPlaceholder
                    }
                }
            } else {
                userPlaceholder
            }
        }
        .frame(width: 32, height: 32)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1.5)
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
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Heart Animation Overlay

    private var heartAnimationOverlay: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 80, weight: .bold))
            .foregroundColor(.red.opacity(0.9))
            .scaleEffect(showHeartAnimation ? 1.2 : 0.5)
            .opacity(showHeartAnimation ? 0.0 : 1.0)
            .animation(.easeOut(duration: 0.6), value: showHeartAnimation)
    }

    // MARK: - Dismiss Button

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Color.black.opacity(0.55), in: Circle())
        }
        .padding(10)
        .buttonStyle(.plain)
        .accessibilityLabel("Dismiss")
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

    static func formatDistance(_ meters: Int) -> String {
        if meters < 10 { return "nearby" }
        if meters < 1000 { return "\(meters)m" }
        let km = Double(meters) / 1000.0
        return String(format: "%.1fkm", km)
    }
}
