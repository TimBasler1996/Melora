import SwiftUI

/// Shows the currently playing Spotify track and allows the user to start/stop broadcasting.
struct NowPlayingView: View {

    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var locationService: LocationService

    @StateObject private var viewModel = NowPlayingViewModel()

    @State private var isShuffleOn: Bool = false

    // Track/location we last pushed into BroadcastManager (to avoid spamming Firestore)
    @State private var lastBroadcastedTrackId: String? = nil
    @State private var lastBroadcastedLocation: LocationPoint? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 18) {
                    header

                    if !spotifyAuth.isAuthorized {
                        connectCard
                    } else {
                        nowPlayingCard
                        controls
                        broadcastCard
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 16)
                .padding(.bottom, 18)
            }
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            locationService.requestAuthorizationIfNeeded()
            viewModel.startAutoRefresh()
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        .onChange(of: viewModel.currentTrack) { _, newTrack in
            guard broadcast.isBroadcasting, let newTrack else { return }
            // Only push when the track actually changed
            if lastBroadcastedTrackId != newTrack.id {
                lastBroadcastedTrackId = newTrack.id
                broadcast.updateTrack(newTrack)
            }
        }
        .onChange(of: locationService.currentLocationPoint) { _, newLoc in
            guard broadcast.isBroadcasting, let newLoc else { return }
            // Avoid spamming tiny location changes (≈ ~10m threshold)
            if let last = lastBroadcastedLocation {
                let dLat = abs(last.latitude - newLoc.latitude)
                let dLon = abs(last.longitude - newLoc.longitude)
                if dLat < 0.0001 && dLon < 0.0001 { return }
            }
            lastBroadcastedLocation = newLoc
            broadcast.updateLocation(newLoc)
        }
        .sheet(isPresented: $viewModel.showingErrorSheet) {
            ErrorSheetView(
                title: "Playback Error",
                message: viewModel.errorMessage ?? "Unknown error"
            )
            .presentationDetents([.medium])
        }
    }

    // MARK: - UI Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Your music, nearby.")
                .font(AppFonts.title())
                .foregroundColor(.white)

            Text("Broadcast what you're listening to so others around you can discover it.")
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Connect Spotify")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.primaryText)

            Text("Log in to show your currently playing track and broadcast it nearby.")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.secondaryText)

            Button {
                spotifyAuth.startAuthorization()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "link")
                    Text("Connect")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.primary)
                )
                .foregroundColor(.white)
            }
        }
        .padding(AppLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(AppLayout.shadowOpacity),
                        radius: AppLayout.shadowRadius,
                        x: 0,
                        y: 10)
        )
    }

    private var nowPlayingCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                artwork

                VStack(alignment: .leading, spacing: 4) {
                    Text(viewModel.currentTrack?.title ?? "Nothing playing")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(2)

                    Text(viewModel.currentTrack?.artist ?? "—")
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)

                    if let album = viewModel.currentTrack?.album, !album.isEmpty {
                        Text(album)
                            .font(AppFonts.footnote())
                            .foregroundColor(AppColors.mutedText)
                            .lineLimit(1)
                    }
                }

                Spacer()
            }

            Divider()

            HStack {
                Text(viewModel.isPlaying ? "Playing" : "Paused")
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.mutedText)

                Spacer()

                if viewModel.isRefreshing {
                    ProgressView().tint(AppColors.primaryText)
                } else {
                    Button {
                        viewModel.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .foregroundColor(AppColors.primaryText)
                }
            }
        }
        .padding(AppLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(AppLayout.shadowOpacity),
                        radius: AppLayout.shadowRadius,
                        x: 0,
                        y: 10)
        )
    }

    private var artwork: some View {
        Group {
            if let urlString = viewModel.currentTrack?.artworkURL,
               let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image.resizable().scaledToFill()
                    case .failure:
                        placeholderArtwork
                    @unknown default:
                        placeholderArtwork
                    }
                }
            } else {
                placeholderArtwork
            }
        }
        .frame(width: 72, height: 72)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppColors.tintedBackground)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.white.opacity(0.85))
            )
    }

    private var controls: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.togglePlayPause()
            } label: {
                Label(viewModel.isPlaying ? "Pause" : "Play",
                      systemImage: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                isShuffleOn.toggle()
                viewModel.setShuffle(isOn: isShuffleOn)
            } label: {
                Label("Shuffle", systemImage: isShuffleOn ? "shuffle.circle.fill" : "shuffle")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private var broadcastCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Broadcast")
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(AppColors.primaryText)

            Text(broadcast.isBroadcasting
                 ? "You're live. Nearby users can see your profile and track."
                 : "Go live to appear in Discover for nearby users.")
            .font(AppFonts.footnote())
            .foregroundColor(AppColors.secondaryText)

            Button {
                handleBroadcastButton()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: broadcast.isBroadcasting ? "stop.circle.fill" : "dot.radiowaves.left.and.right")
                    Text(broadcast.isBroadcasting ? "Stop broadcast" : "Start broadcast")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(broadcast.isBroadcasting ? AppColors.danger : AppColors.primary)
                )
                .foregroundColor(.white)
            }
            .disabled(viewModel.currentTrack == nil && !broadcast.isBroadcasting)

            if let loc = locationService.currentLocationPoint {
                Text("📍 \(loc.latitude, specifier: "%.4f"), \(loc.longitude, specifier: "%.4f")")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(AppColors.mutedText)
            } else {
                Text("📍 Location: —")
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundColor(AppColors.mutedText)
            }
        }
        .padding(AppLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(AppLayout.shadowOpacity),
                        radius: AppLayout.shadowRadius,
                        x: 0,
                        y: 10)
        )
    }

    // MARK: - Actions

    private func handleBroadcastButton() {
        if broadcast.isBroadcasting {
            broadcast.stopBroadcasting()
            lastBroadcastedTrackId = nil
            lastBroadcastedLocation = nil
        } else {
            let loc = locationService.currentLocationPoint

            // Seed "last pushed" values so the next refresh doesn't re-send immediately.
            if let t = viewModel.currentTrack { lastBroadcastedTrackId = t.id }
            if let loc { lastBroadcastedLocation = loc }

            broadcast.startBroadcasting(currentTrack: viewModel.currentTrack, location: loc)
        }
    }
}

private struct ErrorSheetView: View {
    let title: String
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
            Text(message)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
}

