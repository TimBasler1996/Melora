import SwiftUI

struct DiscoverCardView: View {
    let broadcast: DiscoverBroadcast
    let onDismiss: () -> Void
    let onLikeTrack: () -> Void
    let onMessage: (String) -> Void

    var hasLiked: Bool = false
    var hasMessaged: Bool = false

    @State private var isExpanded = false
    @State private var isLiked: Bool = false
    @State private var showHeartAnimation: Bool = false
    @State private var showMessageField: Bool = false
    @State private var messageText: String = ""
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed content (always visible)
            collapsedContent
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                        if !isExpanded {
                            showMessageField = false
                        }
                    }
                }

            // Expanded action row (only when expanded)
            if isExpanded {
                expandedActions

                if showMessageField {
                    messageInputField
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
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
        .onAppear {
            isLiked = hasLiked
        }
    }

    // MARK: - Collapsed Content

    private var collapsedContent: some View {
        HStack(spacing: 12) {
            // User photo (left)
            userThumbnail

            // Text content (center)
            VStack(alignment: .leading, spacing: 3) {
                Text(broadcast.user.displayName)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("\(trackTitle) · \(trackArtist)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                if let distance = broadcast.distanceMeters {
                    Text(formattedDistance(distance))
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer(minLength: 0)

            // Album artwork (right)
            albumArtwork

            // Chevron indicator
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.35))
        }
        .padding(12)
    }

    // MARK: - Expanded Actions

    private var expandedActions: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)

            HStack(spacing: 0) {
                // Like button
                Button(action: handleLikeAction) {
                    HStack(spacing: 6) {
                        Image(systemName: isLiked ? "heart.fill" : "heart")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(isLiked ? .red : .white)
                        Text(isLiked ? "Liked" : "Like")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(isLiked ? .red.opacity(0.8) : .white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(isLiked)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 28)

                // Message button
                Button(action: handleMessageAction) {
                    HStack(spacing: 6) {
                        Image(systemName: hasMessaged ? "paperplane.fill" : "paperplane")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(hasMessaged ? Color(red: 0.2, green: 0.85, blue: 0.4) : .white)
                        Text(hasMessaged ? "Sent" : "Message")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                            .foregroundColor(hasMessaged ? Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8) : .white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                .disabled(hasMessaged)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 28)

                // View Profile button
                NavigationLink {
                    UserProfilePreviewView(userId: broadcast.user.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.circle")
                            .font(.system(size: 16, weight: .medium))
                        Text("Profile")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.85))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)

                // Dismiss button
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 1, height: 28)

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 44)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - Message Input Field

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
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                                     ? .white.opacity(0.3)
                                     : Color(red: 0.2, green: 0.85, blue: 0.4))
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMessageFieldFocused = true
            }
        }
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
        .frame(width: 48, height: 48)
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
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }

    // MARK: - User Thumbnail (compact)

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
        .frame(width: 44, height: 44)
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
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - Actions

    private func handleLikeAction() {
        guard !isLiked else { return }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked = true
            showHeartAnimation = true
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

    // MARK: - Helpers

    private var trackTitle: String {
        let t = broadcast.track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Unknown track" : t
    }

    private var trackArtist: String {
        let a = broadcast.track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? "Unknown artist" : a
    }

    private func formattedDistance(_ meters: Int) -> String {
        if meters > 100 {
            return String(format: "%.1f km away", Double(meters) / 1000.0)
        } else {
            return "\(meters) m away"
        }
    }
}
