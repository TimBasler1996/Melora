import SwiftUI

struct DiscoverView: View {

    @StateObject private var vm = DiscoverViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                content
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { vm.startListening() }
            .onDisappear { vm.stopListening() }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.broadcasters.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading broadcasters…").tint(.white)
                Spacer()
            }
        } else if let error = vm.errorMessage {
            VStack(spacing: 10) {
                Text("Couldn’t load broadcasters")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("Retry") { vm.startListening() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        } else if vm.broadcasters.isEmpty {
            VStack(spacing: 10) {
                Text("No one is live right now")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("When someone nearby starts broadcasting, they’ll show up here.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 40)
        } else {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(vm.broadcasters, id: \.id) { user in
                        DiscoverUserRow(user: user)
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Row: Navigation + Like Button

private struct DiscoverUserRow: View {

    let user: AppUser

    var body: some View {
        HStack(spacing: 10) {

            NavigationLink {
                UserProfileDetailView(userId: user.id)
            } label: {
                DiscoverUserCard(user: user)
            }
            .buttonStyle(.plain)

            DiscoverLikeButton(user: user)
        }
    }
}

private struct DiscoverLikeButton: View {

    let user: AppUser

    @State private var didLike = false
    @State private var isSending = false

    var body: some View {
        Button {
            Task { await like() }
        } label: {
            Image(systemName: didLike ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(didLike ? .red : AppColors.primaryText)
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(AppColors.cardBackground.opacity(0.98))
                )
                .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 6)
        }
        .buttonStyle(.plain)
        .disabled(isSending || didLike || user.currentTrack == nil)
    }

    private func like() async {
        guard let track = user.currentTrack else { return }

        isSending = true
        defer { isSending = false }

        do {
            _ = try await LikeApiService.shared.likeBroadcastTrack(
                fromUser: nil,
                toUser: user,
                track: track,
                sessionLocation: user.lastLocation,
                placeLabel: nil
            )
            didLike = true
        } catch {
            print("❌ Like failed:", error.localizedDescription)
        }
    }
}

// MARK: - Card

private struct DiscoverUserCard: View {

    let user: AppUser

    @Environment(\.openURL) private var openURL

    var body: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                Text(subtitle)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                // ✅ Track row: tap to open Spotify
                if let track = user.currentTrack {
                    Button {
                        openSpotify(for: track)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "spotifyLogo")
                                .hidden() // fallback; we use SF symbols below
                            Image(systemName: "music.note")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.mutedText)

                            Text("\(track.title) · \(track.artist)")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundColor(AppColors.mutedText)
                                .lineLimit(1)

                            Spacer(minLength: 6)

                            Image(systemName: "arrow.up.right.square")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(AppColors.mutedText.opacity(0.9))
                        }
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                    .accessibilityLabel("Open track in Spotify")
                } else if let taste = user.musicTaste, !taste.isEmpty {
                    Text(taste)
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundColor(AppColors.mutedText)
                        .lineLimit(1)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Circle()
                    .fill(AppColors.live)
                    .frame(width: 8, height: 8)
                Text("LIVE")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(AppColors.live)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(AppColors.tintedBackground))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }

    private var subtitle: String {
        let age = user.age.map(String.init) ?? "?"
        let town = (user.hometown ?? "").isEmpty ? "Unknown" : (user.hometown ?? "Unknown")
        return "\(age) · \(town)"
    }

    private var avatar: some View {
        let urlString =
            (user.photoURLs?.first) ??
            user.avatarURL

        return Group {
            if let urlString, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        Circle().fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        initials
                    @unknown default:
                        initials
                    }
                }
            } else {
                initials
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(Circle())
    }

    private var initials: some View {
        ZStack {
            Circle().fill(AppColors.tintedBackground)
            Text(user.initials)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)
        }
    }

    // MARK: - Spotify Deep Link

    private func openSpotify(for track: Track) {
        let spotifyAppURL = URL(string: "spotify:track:\(track.id)")!
        let webURL = URL(string: "https://open.spotify.com/track/\(track.id)")!

        // Try Spotify app first, then web
        openURL(spotifyAppURL) { success in
            if !success {
                openURL(webURL)
            }
        }
    }
}

