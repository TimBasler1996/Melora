import SwiftUI

/// Shows information about the track that the user is currently playing.
/// Includes Spotify auth state, playback controls and a broadcast toggle.
/// Uses LocationService to attach a real GPS location to the broadcast.
struct NowPlayingView: View {
    
    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @EnvironmentObject private var locationService: LocationService
    
    // ✅ NEW: Presence manager (writes to users/{uid} for Discover)
    @EnvironmentObject private var presence: BroadcastPresenceManager
    
    @StateObject private var viewModel = NowPlayingViewModel()
    
    @State private var isSendingPlaybackCommand: Bool = false
    @State private var isPlaying: Bool = true
    @State private var isShuffleOn: Bool = false
    
    // ✅ Prevent writing the same track repeatedly
    @State private var lastSyncedTrackId: String? = nil
    
    // ✅ Für Likes-Inbox
    @State private var showLikesInbox = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 16) {
                
                // HEADER + HEART-BUTTON
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Now playing")
                            .font(AppFonts.title())
                            .foregroundColor(.white)
                        
                        HStack(spacing: 6) {
                            Circle()
                                .fill(spotifyAuth.isAuthorized ? Color.green : Color.yellow)
                                .frame(width: 8, height: 8)
                            Text(spotifyAuth.isAuthorized ? "Connected to Spotify" : "Not connected · Tap to connect")
                                .font(AppFonts.footnote())
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .onTapGesture {
                            spotifyAuth.ensureAuthorized()
                        }
                    }
                    
                    Spacer()
                    
                    Button {
                        showLikesInbox = true
                    } label: {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 20)
                
                // LOCATION (Debug)
                HStack {
                    Image(systemName: "location.fill")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.85))
                    
                    if let loc = locationService.currentLocationPoint {
                        Text(String(format: "Lat %.4f, Lon %.4f", loc.latitude, loc.longitude))
                            .font(AppFonts.footnote())
                            .foregroundColor(.white.opacity(0.85))
                    } else {
                        Text("Getting your location…")
                            .font(AppFonts.footnote())
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, AppLayout.screenPadding)
                
                Spacer(minLength: 0)
                
                mainCard
                
                Spacer(minLength: 0)
                
                Button {
                    viewModel.refresh(showLoadingIndicator: true)
                } label: {
                    HStack(spacing: 6) {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.7)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        Text("Refresh from Spotify")
                    }
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.15))
                    )
                    .foregroundColor(.white)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            locationService.requestAuthorizationIfNeeded()
            viewModel.startAutoRefresh(intervalSeconds: 5)
            viewModel.refresh(showLoadingIndicator: true)
        }
        .onDisappear {
            viewModel.stopAutoRefresh()
        }
        // ✅ Live track updates while broadcasting (no restart needed)
        .onChange(of: viewModel.currentTrack) { _, newTrack in
            guard broadcast.isBroadcasting else { return }
            
            let newId = newTrack?.id
            if newId != lastSyncedTrackId {
                lastSyncedTrackId = newId
                
                // Session/History backend
                if let t = newTrack {
                    broadcast.updateTrack(t)
                }
                
                // Presence backend for Discover
                presence.updateCurrentTrack(newTrack)
            }
        }
        // ✅ LikesInboxView als Sheet
        .sheet(isPresented: $showLikesInbox) {
            LikesInboxView()
        }
    }
    
    // MARK: - Main Card
    
    private var mainCard: some View {
        VStack(spacing: 20) {
            
            if let track = viewModel.currentTrack {
                // Artwork
                artworkView(for: track)
                
                VStack(spacing: 4) {
                    Text(track.title)
                        .font(.system(size: 20, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                    
                    Text(track.artist)
                        .font(.system(size: 15, weight: .regular, design: .rounded))
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(1)
                    
                    if let album = track.album {
                        Text(album)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(AppColors.mutedText)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 24)
                
                playbackControls
                
            } else if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Looking for your current Spotify track…")
                        .font(AppFonts.body())
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 10) {
                    Text("Could not load current track")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                    Text(error)
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            } else {
                VStack(spacing: 10) {
                    Text("No track detected.")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.primaryText)
                    Text("Start playing something on Spotify and pull to refresh.")
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.secondaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
            }
            
            broadcastSection
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
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.bottom, 24)
    }
    
    // MARK: - Artwork
    
    private func artworkView(for track: Track) -> some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(AppColors.tintedBackground)
                            ProgressView()
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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
        .frame(width: 220, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
    
    private var fallbackArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.tintedBackground)
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundColor(.white.opacity(0.85))
        }
    }
    
    // MARK: - Playback Controls
    
    private var playbackControls: some View {
        VStack(spacing: 12) {
            HStack(spacing: 32) {
                Button {
                    sendPlaybackCommand {
                        try await SpotifyPlaybackService.shared.skipToPrevious()
                    }
                } label: {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 20, weight: .semibold))
                }
                
                Button {
                    sendPlaybackCommand {
                        if isPlaying {
                            try await SpotifyPlaybackService.shared.pausePlayback()
                        } else {
                            try await SpotifyPlaybackService.shared.resumePlayback()
                        }
                        isPlaying.toggle()
                    }
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26, weight: .bold))
                }
                
                Button {
                    sendPlaybackCommand {
                        try await SpotifyPlaybackService.shared.skipToNext()
                    }
                } label: {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 20, weight: .semibold))
                }
            }
            .foregroundColor(AppColors.primaryText)
            
            Button {
                let newValue = !isShuffleOn
                sendPlaybackCommand {
                    try await SpotifyPlaybackService.shared.setShuffle(enabled: newValue)
                    isShuffleOn = newValue
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                    Text(isShuffleOn ? "Shuffle on" : "Shuffle off")
                }
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isShuffleOn ? AppColors.primary.opacity(0.16) : Color.gray.opacity(0.12))
                )
                .foregroundColor(isShuffleOn ? AppColors.primary : AppColors.secondaryText)
            }
            .disabled(isSendingPlaybackCommand)
        }
        .padding(.top, 8)
    }
    
    private func sendPlaybackCommand(_ action: @escaping () async throws -> Void) {
        guard !isSendingPlaybackCommand else { return }
        isSendingPlaybackCommand = true
        
        Task {
            defer { isSendingPlaybackCommand = false }
            do {
                try await action()
                await viewModel.refresh(showLoadingIndicator: false)
            } catch {
                print("❌ Spotify playback command failed: \(error)")
            }
        }
    }
    
    // MARK: - Broadcast Section
    
    private var broadcastSection: some View {
        VStack(spacing: 10) {
            HStack {
                Label {
                    Text(broadcast.isBroadcasting ? "Broadcasting live" : "Not broadcasting")
                } icon: {
                    Circle()
                        .fill(broadcast.isBroadcasting ? AppColors.live : Color.gray.opacity(0.7))
                        .frame(width: 8, height: 8)
                }
                .font(.caption)
                .foregroundColor(AppColors.secondaryText)
                
                Spacer()
            }
            
            if let err = presence.lastError {
                Text(err)
                    .font(AppFonts.footnote())
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            Button {
                handleBroadcastButton()
            } label: {
                Text(broadcast.isBroadcasting ? "Stop broadcast" : "Start broadcast")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                            .fill(broadcast.isBroadcasting ? Color.red.opacity(0.9) : AppColors.primary)
                    )
                    .foregroundColor(.white)
            }
        }
    }
    
    private func handleBroadcastButton() {
        if broadcast.isBroadcasting {
            broadcast.stopBroadcasting()
            presence.stopBroadcast()
            lastSyncedTrackId = nil
        } else {
            let loc = locationService.currentLocationPoint
            let track = viewModel.currentTrack
            
            // Start session/history broadcast
            broadcast.startBroadcasting(currentTrack: track, location: loc)
            
            // Start presence broadcast for Discover
            presence.startBroadcast(currentLocation: loc, currentTrack: track)
            
            lastSyncedTrackId = track?.id
        }
    }
}

