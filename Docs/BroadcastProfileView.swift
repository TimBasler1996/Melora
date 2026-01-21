import SwiftUI

import SwiftUI

/// Premium profile view shown when tapping a broadcast card
/// Displays user photos, info, and interaction state in a clean, dating-app style
struct BroadcastProfileView: View {
    
    let broadcast: DiscoverBroadcast
    let hasAlreadyLiked: Bool
    let hasAlreadyMessaged: Bool
    let onLike: () -> Void
    let onMessage: (String) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    @State private var messageText: String = ""
    @State private var showMessageField: Bool = false
    
    private let heroImageHeight: CGFloat = 480
    
    var body: some View {
        ZStack {
            // Premium dark gradient background
            LinearGradient(
                colors: [
                    Color(red: 0.12, green: 0.12, blue: 0.18),
                    Color.black.opacity(0.98)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    // Hero image with gradient overlay
                    heroSection
                    
                    // User info and actions
                    contentSection
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                }
            }
            
            // Close button overlay
            VStack {
                HStack {
                    Spacer()
                    closeButton
                        .padding(.trailing, 20)
                        .padding(.top, 12)
                }
                Spacer()
            }
        }
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Hero Section
    
    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Hero image with clean, non-cropped display
            heroImage
            
            // Gradient overlay for text readability
            LinearGradient(
                colors: [
                    Color.clear,
                    Color.black.opacity(0.3),
                    Color.black.opacity(0.75)
                ],
                startPoint: .center,
                endPoint: .bottom
            )
            
            // Name and age overlay
            VStack(alignment: .leading, spacing: 4) {
                Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 2)
                
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 14, weight: .medium))
                    Text("\(broadcast.user.locationText)")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                    
                    if let distance = broadcast.distanceMeters {
                        Text("· \(distance)m away")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                    }
                }
                .foregroundColor(.white.opacity(0.9))
                .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(height: heroImageHeight)
    }
    
    private var heroImage: some View {
        Group {
            if let urlString = broadcast.user.primaryPhotoURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        heroPlaceholder
                    case .success(let image):
                        // Clean, well-displayed image
                        ZStack {
                            // Blurred background to fill any gaps
                            image
                                .resizable()
                                .scaledToFill()
                                .blur(radius: 20)
                                .opacity(0.4)
                            
                            // Main image, nicely fitted
                            image
                                .resizable()
                                .scaledToFit()
                                .transaction { $0.animation = nil }
                        }
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
        .frame(height: heroImageHeight)
        .clipped()
    }
    
    private var heroPlaceholder: some View {
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
                .font(.system(size: 60, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
    }
    
    // MARK: - Content Section
    
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            // User info chips
            infoChipsSection
            
            // Currently playing track
            currentlyPlayingSection
            
            // Additional photos
            if !broadcast.user.photoURLs.isEmpty {
                additionalPhotosSection
            }
            
            // Action buttons
            actionButtonsSection
            
            // Message field (if shown)
            if showMessageField {
                messageSection
            }
        }
        .padding(.top, 24)
    }
    
    // MARK: - Info Chips
    
    private var infoChipsSection: some View {
        HStack(spacing: 10) {
            if let gender = broadcast.user.gender?.trimmingCharacters(in: .whitespacesAndNewlines),
               !gender.isEmpty {
                InfoChip(icon: "person.fill", text: gender)
            }
            
            if let countryCode = broadcast.user.countryCode?.trimmingCharacters(in: .whitespacesAndNewlines),
               !countryCode.isEmpty {
                InfoChip(icon: "globe", text: countryCode.uppercased())
            }
            
            Spacer()
        }
    }
    
    // MARK: - Currently Playing
    
    private var currentlyPlayingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Currently Broadcasting")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)
            
            HStack(spacing: 14) {
                // Track artwork
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
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(broadcast.track.title)
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    Text(broadcast.track.artist)
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                    
                    if let album = broadcast.track.album {
                        Text(album)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                }
                
                Spacer()
                
                // Spotify link
                if let url = broadcast.track.spotifyURLValue {
                    Link(destination: url) {
                        Image(systemName: "music.note")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                            .frame(width: 40, height: 40)
                            .background(
                                Circle()
                                    .fill(Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.15))
                            )
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.06))
            )
            
            // Interaction state badges directly below the track (if already interacted)
            if hasAlreadyLiked || hasAlreadyMessaged {
                HStack(spacing: 10) {
                    if hasAlreadyLiked {
                        InteractionBadge(
                            icon: "heart.fill",
                            text: "You liked this track",
                            color: Color(red: 1.0, green: 0.27, blue: 0.33)
                        )
                    }
                    
                    if hasAlreadyMessaged {
                        InteractionBadge(
                            icon: "message.fill",
                            text: "You messaged about this",
                            color: Color(red: 0.2, green: 0.85, blue: 0.4)
                        )
                    }
                    
                    Spacer()
                }
            }
        }
    }
    
    private var artworkPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.15), Color.white.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.white.opacity(0.4))
        }
    }
    
    // MARK: - Additional Photos
    
    private var additionalPhotosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("More Photos")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
                .textCase(.uppercase)
                .tracking(0.5)
            
            LazyVStack(spacing: 12) {
                ForEach(Array(broadcast.user.photoURLs.prefix(6).enumerated()), id: \.offset) { _, urlString in
                    if let url = URL(string: urlString), urlString != broadcast.user.primaryPhotoURL {
                        photoCard(url: url)
                    }
                }
            }
        }
    }
    
    private func photoCard(url: URL) -> some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .empty:
                photoPlaceholder
            case .success(let image):
                ZStack {
                    // Background blur
                    image
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 15)
                        .opacity(0.4)
                    
                    // Main image, well-fitted
                    image
                        .resizable()
                        .scaledToFit()
                        .transaction { $0.animation = nil }
                }
            case .failure:
                photoPlaceholder
            @unknown default:
                photoPlaceholder
            }
        }
        .frame(height: 280)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
    }
    
    private var photoPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.1),
                    Color.white.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "photo.fill")
                .font(.system(size: 32, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
    }
    
    // MARK: - Action Buttons
    
    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Like button
            Button(action: {
                onLike()
                dismiss()
            }) {
                HStack(spacing: 12) {
                    Image(systemName: hasAlreadyLiked ? "heart.fill" : "heart")
                        .font(.system(size: 18, weight: .bold))
                    Text(hasAlreadyLiked ? "You liked this track" : "Like this track")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(hasAlreadyLiked 
                            ? Color(red: 1.0, green: 0.27, blue: 0.33).opacity(0.6)
                            : Color(red: 1.0, green: 0.27, blue: 0.33)
                        )
                )
            }
            .disabled(hasAlreadyLiked)
            
            // Message button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showMessageField.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: hasAlreadyMessaged ? "message.fill" : "message")
                        .font(.system(size: 18, weight: .bold))
                    Text(hasAlreadyMessaged ? "Already sent message" : "Message about this track")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.4).opacity(hasAlreadyMessaged ? 0.4 : 0.85))
                )
            }
        }
    }
    
    // MARK: - Message Section
    
    private var messageSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your message")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            
            TextField("Say something nice…", text: $messageText, axis: .vertical)
                .font(.system(size: 16, weight: .regular, design: .rounded))
                .foregroundColor(.white)
                .padding(14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color.white.opacity(0.08))
                )
                .lineLimit(3...6)
            
            Button {
                let trimmed = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return }
                onMessage(trimmed)
                messageText = ""
                showMessageField = false
                dismiss()
            } label: {
                HStack {
                    Spacer()
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16, weight: .bold))
                    Text("Send")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Spacer()
                }
                .foregroundColor(.white)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(red: 0.2, green: 0.85, blue: 0.4))
                )
            }
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .transition(.opacity.combined(with: .move(edge: .top)))
    }
    
    // MARK: - Close Button
    
    private var closeButton: some View {
        Button(action: { dismiss() }) {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(Color.black.opacity(0.7))
                        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Supporting Views

private struct InfoChip: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
            Text(text)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white.opacity(0.85))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct InteractionBadge: View {
    let icon: String
    let text: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
            Text(text)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
        }
        .foregroundColor(color)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Preview

#Preview {
    BroadcastProfileView(
        broadcast: DiscoverBroadcast(
            id: "preview",
            user: DiscoverUser(
                id: "user1",
                firstName: "Sarah",
                lastName: "Mitchell",
                age: 28,
                city: "Berlin",
                gender: "Female",
                countryCode: "DE",
                heroPhotoURL: nil,
                profilePhotoURL: nil,
                photoURLs: []
            ),
            track: DiscoverTrack(
                id: "track1",
                title: "Electric Feel",
                artist: "MGMT",
                album: "Oracular Spectacular",
                artworkURL: nil,
                spotifyTrackURL: nil
            ),
            broadcastedAt: Date(),
            location: nil,
            distanceMeters: 450
        ),
        hasAlreadyLiked: false,
        hasAlreadyMessaged: false,
        onLike: {},
        onMessage: { _ in }
    )
}
