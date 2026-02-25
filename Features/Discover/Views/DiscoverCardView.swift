import SwiftUI

/// Compact, expandable Discover Card matching the design:
/// - Collapsed: User photo (left) · Name / Track · Artist / Distance · Album art (right) · Chevron
/// - Expanded: + divider + 4 action buttons (Like, Message, Profile, X)
struct DiscoverCardView: View {
    let broadcast: DiscoverBroadcast
    @Binding var isExpanded: Bool
    let onDismiss: () -> Void
    let onLikeTrack: () -> Void
    let onMessage: (String) -> Void
    let onViewProfile: () -> Void

    var hasLiked: Bool = false
    var hasMessaged: Bool = false

    @State private var isLiked: Bool = false
    @State private var showHeartAnimation: Bool = false
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

                    if showMessageField {
                        messageInputField
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.09))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)

            // Heart animation overlay
            if showHeartAnimation {
                heartAnimationOverlay
            }
        }
        .onAppear {
            isLiked = hasLiked
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
            VStack(alignment: .leading, spacing: 4) {
                Text(broadcast.user.displayName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(trackTitle) · \(trackArtist)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                if let distance = broadcast.distanceMeters {
                    Text("\(Self.formatDistance(distance)) away")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer(minLength: 0)

            // Album artwork (square) on the RIGHT
            albumArtwork

            // Chevron
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Divider

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 14)
    }

    // MARK: - 4 Action Buttons (Like, Message, Profile, X)

    private var actionButtonsRow: some View {
        HStack(spacing: 0) {
            // 1. Like
            actionButton(
                icon: isLiked ? "heart.fill" : "heart",
                label: "Like",
                color: isLiked ? .red : .white
            ) {
                handleLikeAction()
            }

            // 2. Message
            actionButton(
                icon: hasMessaged ? "paperplane.fill" : "paperplane",
                label: "Message",
                color: hasMessaged ? Color(red: 0.2, green: 0.85, blue: 0.4) : .white
            ) {
                handleMessageAction()
            }

            // 3. Profile
            actionButton(
                icon: "person.crop.circle",
                label: "Profile",
                color: .white
            ) {
                onViewProfile()
            }

            // 4. Dismiss (X)
            actionButton(
                icon: "xmark",
                label: "",
                color: .white.opacity(0.6)
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
        color: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(color)

                if !label.isEmpty {
                    Text(label)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundColor(color.opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
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

    // MARK: - User Photo (circle, left side)

    private var userPhoto: some View {
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
        .frame(width: 50, height: 50)
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
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Album Artwork (square, right side)

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
        .frame(width: 50, height: 50)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
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
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
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
        return String(format: "%.1f km", km)
    }
}
