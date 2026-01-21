import SwiftUI

struct DiscoverCardView: View {
    let broadcast: DiscoverBroadcast
    let onTap: () -> Void
    let onDismiss: () -> Void
    let onLikeTrack: () -> Void
    let onMessage: (String) -> Void
    
    var hasLiked: Bool = false
    var hasMessaged: Bool = false
    
    @State private var isLiked: Bool = false
    @State private var showHeartAnimation: Bool = false
    @State private var showMessageField: Bool = false
    @State private var messageText: String = ""
    @FocusState private var isMessageFieldFocused: Bool

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Main card content
                VStack(spacing: 0) {
                    HStack(spacing: 18) {
                        // Large album artwork on the left
                        albumArtwork
                        
                        // Content on the right
                        VStack(alignment: .leading, spacing: 12) {
                            // Track info
                            VStack(alignment: .leading, spacing: 4) {
                                Text(trackTitle)
                                    .font(.system(size: 20, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                Text(trackArtist)
                                    .font(.system(size: 16, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.75))
                                    .lineLimit(1)
                            }
                            
                            Spacer(minLength: 8)
                            
                            // User info with LARGER photo
                            HStack(spacing: 12) {
                                userThumbnail
                                
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    HStack(spacing: 6) {
                                        Image(systemName: "location.fill")
                                            .font(.system(size: 11))
                                        Text("\(broadcast.user.locationText)")
                                            .font(.system(size: 13, weight: .medium, design: .rounded))
                                        
                                        if let distance = broadcast.distanceMeters {
                                            Text("· \(distance)m")
                                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                        }
                                    }
                                    .foregroundColor(.white.opacity(0.65))
                                }
                                
                                Spacer(minLength: 0)
                            }
                        }
                        .padding(.vertical, 20)
                        .padding(.trailing, 16)
                    }
                    .padding(.leading, 20)
                    
                    // Modern action buttons (Instagram style)
                    modernActionButtons
                    
                    // Inline message field (only shown when message icon is tapped)
                    if showMessageField {
                        messageInputField
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.25), radius: 16, x: 0, y: 8)

                dismissButton
                
                // Heart animation overlay
                if showHeartAnimation {
                    heartAnimationOverlay
                }
            }
        }
        .buttonStyle(.plain)
        .onAppear {
            isLiked = hasLiked
        }
    }
    
    // MARK: - Modern Action Buttons (Instagram Style)
    
    private var modernActionButtons: some View {
        HStack(spacing: 20) {
            // Like button (heart icon)
            Button(action: handleLikeAction) {
                VStack(spacing: 4) {
                    Image(systemName: isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(isLiked ? .red : .white)
                        .scaleEffect(showHeartAnimation ? 1.3 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.5), value: showHeartAnimation)
                }
            }
            .buttonStyle(.plain)
            .disabled(isLiked)
            
            // Message button
            Button(action: handleMessageAction) {
                VStack(spacing: 4) {
                    Image(systemName: hasMessaged ? "paperplane.fill" : "paperplane")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(hasMessaged ? Color(red: 0.2, green: 0.85, blue: 0.4) : .white)
                }
            }
            .buttonStyle(.plain)
            .disabled(hasMessaged)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, showMessageField ? 8 : 20)
    }
    
    // MARK: - Message Input Field
    
    private var messageInputField: some View {
        HStack(spacing: 12) {
            TextField("Send a message...", text: $messageText, axis: .vertical)
                .focused($isMessageFieldFocused)
                .font(.system(size: 15, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .lineLimit(1...4)
            
            // Send button
            Button(action: handleSendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty 
                                     ? .white.opacity(0.3) 
                                     : Color(red: 0.2, green: 0.85, blue: 0.4))
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMessageFieldFocused = true
            }
        }
    }
    
    // MARK: - Heart Animation Overlay
    
    private var heartAnimationOverlay: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 100, weight: .bold))
            .foregroundColor(.red.opacity(0.9))
            .scaleEffect(showHeartAnimation ? 1.2 : 0.5)
            .opacity(showHeartAnimation ? 0.0 : 1.0)
            .animation(.easeOut(duration: 0.6), value: showHeartAnimation)
    }
    
    // MARK: - Actions
    
    private func handleLikeAction() {
        guard !isLiked else { return }
        
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            isLiked = true
            showHeartAnimation = true
        }
        
        // Trigger heart pop animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                showHeartAnimation = false
            }
        }
        
        // Reset animation state
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

    // MARK: - Album Artwork (Large, prominent)
    
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
        .frame(width: 140, height: 140)
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
                .font(.system(size: 40, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    // MARK: - User Thumbnail (Larger, more prominent)
    
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
        .frame(width: 56, height: 56)
        .clipShape(Circle())
        .overlay(
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 2.5)
        )
        .shadow(color: Color.black.opacity(0.2), radius: 4, x: 0, y: 2)
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
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    // MARK: - OLD (TO BE REMOVED)

    /// Top: Spotify-style row (like your screenshot)
    private var trackModule: some View {
        HStack(spacing: 14) {
            trackArtworkThumbnail

            VStack(alignment: .leading, spacing: 6) {
                Text(trackTitle)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(trackArtist)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                if let album = trackAlbum {
                    Text(album)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            spotifyPill
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    /// Bottom: Profile row in same style (no hero crop)
    private var profileModule: some View {
        HStack(spacing: 14) {
            heroThumbnailNoCrop

            VStack(alignment: .leading, spacing: 6) {
                Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)

                Text("\(broadcast.user.locationText) · \(distanceText)")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(1)

                if let badgeText = badgeText {
                    profileChip(text: badgeText)
                }
            }

            Spacer(minLength: 0)

            // Subtle “tap hint” like dating apps
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private var moduleDivider: some View {
        Rectangle()
            .fill(Color.white.opacity(0.1))
            .frame(height: 1)
            .padding(.horizontal, 16)
    }

    // MARK: - Track UI

    private var trackArtworkThumbnail: some View {
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
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var spotifyPill: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 12, weight: .semibold))
            Text("Spotify")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.7))
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.white.opacity(0.1))
        .clipShape(Capsule())
    }

    // MARK: - Profile UI (NO CROP HERO)

    /// Hero thumbnail where the image is NOT cropped:
    /// - Use scaledToFit inside a fixed frame
    /// - Provide a subtle background so letterboxing looks intentional
    private var heroThumbnailNoCrop: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))

            if let url = broadcast.user.primaryPhotoURL.flatMap(URL.init(string:)) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        heroPlaceholder
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit() // IMPORTANT: no crop
                            .padding(6)     // keeps it clean inside frame
                            .transaction { $0.animation = nil }
                    case .failure:
                        heroPlaceholder
                    @unknown default:
                        heroPlaceholder
                    }
                }
            } else {
                heroPlaceholder
            }
        }
        .frame(width: 58, height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
    }

    private var heroPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "person.fill")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(8)
    }

    private func profileChip(text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.2))
            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
            .clipShape(Capsule())
    }

    // MARK: - Dismiss

    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 34, height: 34)
                .background(Color.black.opacity(0.60), in: Circle())
        }
        .padding(14)
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

    private var trackAlbum: String? {
        guard let album = broadcast.track.album else { return nil }
        let trimmed = album.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var badgeText: String? {
        // Implement badge text logic if needed
        return nil
    }

    private var distanceText: String {
        guard let distance = broadcast.distanceMeters else { return "Unknown" }
        return "\(distance)m"
    }
}

