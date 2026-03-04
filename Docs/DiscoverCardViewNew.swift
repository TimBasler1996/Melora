import SwiftUI

/// Improved Discover Card - Compact, visually balanced design
/// Shows large album artwork with track and user info side-by-side
struct DiscoverCardViewNew: View {
    let broadcast: DiscoverBroadcast
    let onTap: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .topTrailing) {
                // Main card content
                HStack(spacing: 16) {
                    // Large album artwork on the left
                    albumArtwork
                    
                    // Content on the right
                    VStack(alignment: .leading, spacing: 10) {
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
                        
                        // User info with photo
                        HStack(spacing: 10) {
                            userThumbnail
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(broadcast.user.displayName), \(broadcast.user.ageText)")
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
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
            }
        }
        .buttonStyle(.plain)
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
    
    // MARK: - User Thumbnail (Small, circular)
    
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
                .stroke(Color.white.opacity(0.25), lineWidth: 2)
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

    // MARK: - Dismiss Button
    
    private var dismissButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "xmark")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(Color.black.opacity(0.60), in: Circle())
        }
        .padding(12)
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
}

