import SwiftUI
import CoreLocation

/// One card representing a single broadcast session in the Nearby screen.
/// Supports expand/collapse to show a larger music card popup.
struct SessionRowView: View {

    @Binding var session: Session
    let userLocation: LocationPoint?
    @Binding var isExpanded: Bool

    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 0) {
            // Collapsed row — tap to expand/collapse
            Button {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                collapsedRow
            }
            .buttonStyle(.plain)

            // Expanded: large music card popup
            if isExpanded {
                expandedContent
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }

    // MARK: - Collapsed Row

    private var collapsedRow: some View {
        HStack(spacing: 12) {
            artwork(size: 56)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(session.user.displayName)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)

                    Spacer()

                    HStack(spacing: 4) {
                        Circle()
                            .fill(AppColors.live)
                            .frame(width: 6, height: 6)

                        Text("LIVE")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundColor(AppColors.live)
                    }
                }

                Text(session.track.title)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                Text(session.track.artist)
                    .font(.system(size: 13, weight: .regular, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                if let distanceText {
                    Text(distanceText)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(AppColors.mutedText)
                        .lineLimit(1)
                }
            }

            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(AppColors.mutedText)
        }
        .padding(12)
    }

    // MARK: - Expanded Content (Music Card Popup)

    private var expandedContent: some View {
        VStack(spacing: 16) {
            // Divider
            Rectangle()
                .fill(Color.white.opacity(0.1))
                .frame(height: 1)
                .padding(.horizontal, 14)

            // Large artwork
            artwork(size: 200)
                .padding(.horizontal, 40)

            // Track details
            VStack(spacing: 4) {
                Text(session.track.title)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)

                Text(session.track.artist)
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                if let album = session.track.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundColor(AppColors.mutedText)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, 20)

            // Action buttons
            HStack(spacing: 16) {
                // Open in Spotify
                if let trackId = session.track.id as String? {
                    Button {
                        let appURL = URL(string: "spotify:track:\(trackId)")!
                        let webURL = URL(string: "https://open.spotify.com/track/\(trackId)")!
                        openURL(appURL) { success in
                            if !success { openURL(webURL) }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12, weight: .bold))
                            Text("Spotify")
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Color(red: 0.11, green: 0.73, blue: 0.33)))
                    }
                    .buttonStyle(.plain)
                }

                // View Profile
                NavigationLink {
                    OtherUserProfileLoaderView(uid: session.user.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12, weight: .bold))
                        Text("Profile")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(AppColors.primaryText)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, 16)
        }
    }

    // MARK: - Artwork

    private func artwork(size: CGFloat) -> some View {
        Group {
            if let url = session.track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        fallbackArtwork
                    @unknown default:
                        fallbackArtwork
                    }
                }
            } else {
                fallbackArtwork
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var fallbackArtwork: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(AppColors.tintedBackground)
            .overlay(
                Image(systemName: "music.note")
                    .foregroundColor(AppColors.primaryText)
            )
    }

    // MARK: - Distance

    private var distanceText: String? {
        guard let userLoc = userLocation else { return nil }

        let sessionLoc = session.location

        let a = CLLocation(latitude: userLoc.latitude, longitude: userLoc.longitude)
        let b = CLLocation(latitude: sessionLoc.latitude, longitude: sessionLoc.longitude)
        let meters = a.distance(from: b)

        if meters < 10 {
            return "Nearby"
        } else if meters < 1000 {
            return "\(Int(meters)) m away"
        } else {
            return String(format: "%.1f km away", meters / 1000.0)
        }
    }
}

//
// MARK: - Loader: fetch AppUser then show profile
//

struct OtherUserProfileLoaderView: View {

    let uid: String

    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var user: AppUser?

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            content
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { load() }
    }

    @ViewBuilder
    private var content: some View {
        if isLoading {
            VStack {
                Spacer()
                ProgressView("Loading profile…")
                    .tint(.white)
                Spacer()
            }
        } else if let errorMessage {
            VStack(spacing: 10) {
                Text("Couldn't load profile")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(errorMessage)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("Retry") { load() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)

        } else if let user {
            OtherUserProfileView(user: user)
        } else {
            VStack {
                Spacer()
                Text("No profile found.")
                    .foregroundColor(.white)
                Spacer()
            }
        }
    }

    private func load() {
        isLoading = true
        errorMessage = nil
        user = nil

        UserApiService.shared.getUser(uid: uid) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .failure(let error):
                    self.errorMessage = error.localizedDescription
                case .success(let user):
                    self.user = user
                }
            }
        }
    }
}
