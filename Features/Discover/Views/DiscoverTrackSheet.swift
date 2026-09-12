import SwiftUI

/// The song is the hero: tapping a track in Discover opens this sheet.
///
/// Top: the cover, large, tinting the sheet. Then who is playing it, one
/// primary action (play it on Spotify right now), and the ways to react —
/// like, message, queue, save, share. Hiding the song lives at the bottom.
struct DiscoverTrackSheet: View {
    let broadcast: DiscoverBroadcast
    var hasLiked: Bool = false
    var hasMessaged: Bool = false

    let onLike: () -> Void
    let onMessage: (String) -> Void
    let onOpenChat: () -> Void
    let onViewProfile: () -> Void
    let onHideTrack: () -> Void

    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var glow: Color?

    // Spotify state
    @State private var playState: PlayState = .idle
    @State private var isSaved: Bool = false
    @State private var isSaving: Bool = false
    @State private var isQueueing: Bool = false
    @State private var status: Status?
    @State private var statusToken: Int = 0

    // Message composer
    @State private var showMessageField: Bool = false
    @State private var messageText: String = ""
    @FocusState private var isMessageFieldFocused: Bool

    @State private var likeBurst: Int = 0
    @State private var showLikeBurst: Bool = false

    private enum PlayState: Equatable {
        case idle, starting, playing, opened
    }

    /// A line under the primary button: what just happened, or what to do.
    private struct Status: Equatable {
        enum Kind { case info, success, reconnect }
        let text: String
        let kind: Kind
    }

    private var track: DiscoverTrack { broadcast.track }

    private var spotifyWebURL: URL {
        track.spotifyURLValue ?? URL(string: "https://open.spotify.com/track/\(track.id)")!
    }

    private var spotifyDeepLink: URL {
        URL(string: "spotify:track:\(track.id)")!
    }

    var body: some View {
        ZStack(alignment: .top) {
            background

            ScrollView {
                VStack(spacing: 22) {
                    header
                    playingBy
                    primaryAction
                    actionRow
                    if showMessageField {
                        messageInputField
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    footer
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.top, 52)
                .padding(.bottom, 28)
            }
            .scrollIndicators(.hidden)

            closeButton
        }
        .presentationDragIndicator(.visible)
        .presentationBackground(AppColors.background)
        .task(id: track.artworkURL) {
            guard let url = track.artworkURLValue else { glow = nil; return }
            glow = await ArtworkColorCache.shared.color(for: url)
        }
        .task { await loadSavedState() }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: status)
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: playState)
    }

    // MARK: - Background

    private var background: some View {
        ZStack {
            AppColors.background
            if let glow {
                RadialGradient(
                    colors: [glow.opacity(0.6), glow.opacity(0.0)],
                    center: .top,
                    startRadius: 0,
                    endRadius: 420
                )
            }
        }
        .ignoresSafeArea()
    }

    private var closeButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                MIcon("x", size: 16, color: AppColors.primaryText)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(AppColors.surface))
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close")
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 14)
    }

    // MARK: - Header (artwork + titles)

    private var header: some View {
        VStack(spacing: 18) {
            ZStack {
                artwork
                if showLikeBurst {
                    RippleBurst(size: 260, trigger: likeBurst)
                }
            }

            VStack(spacing: 6) {
                Text(trackTitle)
                    .font(AppFonts.song(size: 30))
                    .foregroundColor(AppColors.primaryText)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text(trackArtist)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                if let album = track.album?.trimmingCharacters(in: .whitespacesAndNewlines), !album.isEmpty {
                    Text(album)
                        .font(AppFonts.footnote())
                        .foregroundColor(AppColors.mutedText)
                        .lineLimit(1)
                }
            }
        }
    }

    private var artwork: some View {
        ZStack {
            if let url = track.artworkURLValue {
                RemoteImage(url: url, size: 220) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        artworkPlaceholder
                    }
                }
            } else {
                artworkPlaceholder
            }
        }
        .frame(width: 220, height: 220)
        .clipShape(RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .stroke(AppColors.stroke, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 24, x: 0, y: 14)
    }

    private var artworkPlaceholder: some View {
        ZStack {
            AppColors.surfaceElevated
            MIcon("music", size: 48, color: AppColors.mutedText)
        }
    }

    // MARK: - Playing by

    private var playingBy: some View {
        Button(action: onViewProfile) {
            HStack(spacing: 12) {
                userPhoto

                VStack(alignment: .leading, spacing: 3) {
                    Text(broadcast.isLive ? "Playing now by" : "Played by")
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.mutedText)
                        .textCase(.uppercase)
                        .tracking(0.6)

                    Text(broadcast.user.displayName)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(AppColors.primaryText)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if broadcast.isLive {
                            RippleMark(size: 12, rings: 1)
                            Text("Live")
                                .fontWeight(.bold)
                                .foregroundColor(AppColors.live)
                        } else {
                            Text("Live \(broadcast.lastSeenText)")
                                .foregroundColor(AppColors.secondaryText)
                        }
                        if let distance = broadcast.distanceMeters {
                            Text("· \(DiscoverCardView.formatDistance(distance))")
                                .foregroundColor(AppColors.secondaryText)
                        } else if !broadcast.user.locationText.isEmpty {
                            Text("· \(broadcast.user.locationText)")
                                .foregroundColor(AppColors.secondaryText)
                        }
                    }
                    .font(.system(size: 12, weight: .medium))
                }

                Spacer(minLength: 0)

                MIcon("chev-right", size: 16, color: AppColors.mutedText)
            }
            .padding(14)
            .melCard(cornerRadius: 16)
        }
        .buttonStyle(.pressable)
        .accessibilityLabel("View \(broadcast.user.displayName)’s profile")
    }

    private var userPhoto: some View {
        ZStack {
            if let urlString = broadcast.user.primaryPhotoURL, let url = URL(string: urlString) {
                RemoteImage(url: url, size: 44) { phase in
                    if case .success(let image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        userPlaceholder
                    }
                }
            } else {
                userPlaceholder
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(Circle())
        .overlay(Circle().stroke(AppColors.stroke, lineWidth: 1.5))
    }

    private var userPlaceholder: some View {
        ZStack {
            AppColors.surfaceElevated
            MIcon("person", size: 18, color: AppColors.mutedText)
        }
    }

    // MARK: - Primary action: play it now

    private var primaryAction: some View {
        VStack(spacing: 10) {
            Button(action: handlePlay) {
                HStack(spacing: 10) {
                    switch playState {
                    case .starting:
                        ProgressView().tint(AppColors.background).scaleEffect(0.85)
                    case .playing:
                        MIcon("check", size: 18, color: AppColors.background)
                    case .opened:
                        MIcon("arrow-up-right", size: 18, color: AppColors.background)
                    case .idle:
                        MIcon("play", size: 18, color: AppColors.background)
                    }
                    Text(primaryTitle)
                        .font(.system(size: 16, weight: .heavy))
                        .foregroundColor(AppColors.background)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(Capsule().fill(AppColors.primary))
            }
            .buttonStyle(.pressable)
            .disabled(playState == .starting)

            if let status {
                statusLine(status)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var primaryTitle: String {
        switch playState {
        case .idle: return spotifyAuth.isAuthorized ? "Play on Spotify" : "Open in Spotify"
        case .starting: return "Starting…"
        case .playing: return "Playing on Spotify"
        case .opened: return "Opened in Spotify"
        }
    }

    private func statusLine(_ status: Status) -> some View {
        HStack(spacing: 8) {
            Text(status.text)
                .font(AppFonts.footnote())
                .foregroundColor(status.kind == .success ? AppColors.primaryText : AppColors.secondaryText)
                .multilineTextAlignment(.center)

            if status.kind == .reconnect {
                Button("Reconnect") {
                    spotifyAuth.reconnect()
                    self.status = nil
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(AppColors.primary)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 0) {
            actionButton(
                icon: hasLiked ? "heart-fill" : "heart",
                label: hasLiked ? "Liked" : "Like",
                color: hasLiked ? AppColors.live : AppColors.primaryText
            ) {
                handleLike()
            }

            actionButton(
                icon: "send",
                label: hasMessaged ? "Open chat" : "Message",
                color: hasMessaged ? AppColors.live : AppColors.primaryText
            ) {
                handleMessageAction()
            }

            actionButton(
                icon: "next",
                label: "Queue",
                color: AppColors.primaryText,
                isBusy: isQueueing
            ) {
                handleQueue()
            }

            actionButton(
                icon: isSaved ? "check" : "plus",
                label: isSaved ? "Saved" : "Save",
                color: isSaved ? AppColors.live : AppColors.primaryText,
                isBusy: isSaving
            ) {
                handleSave()
            }

            ShareLink(item: spotifyWebURL, message: Text("\(trackTitle) – \(trackArtist)")) {
                actionLabel(icon: "arrow-up-right", label: "Share", color: AppColors.primaryText)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .melCard(cornerRadius: 16)
    }

    private func actionButton(
        icon: String,
        label: String,
        color: Color,
        isBusy: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            actionLabel(icon: icon, label: label, color: color, isBusy: isBusy)
        }
        .buttonStyle(.plain)
        .disabled(isBusy)
        .accessibilityLabel(label)
    }

    private func actionLabel(icon: String, label: String, color: Color, isBusy: Bool = false) -> some View {
        VStack(spacing: 6) {
            ZStack {
                MIcon(icon, size: 22, color: color)
                    .opacity(isBusy ? 0 : 1)
                if isBusy {
                    ProgressView().tint(AppColors.primaryText).scaleEffect(0.7)
                }
            }
            .frame(height: 22)

            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(color.opacity(0.85))
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }

    // MARK: - Message composer

    private var messageInputField: some View {
        HStack(spacing: 10) {
            TextField("Say something about the song…", text: $messageText, axis: .vertical)
                .focused($isMessageFieldFocused)
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(AppColors.primaryText)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppColors.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppColors.stroke, lineWidth: 1)
                )
                .lineLimit(1...3)

            Button(action: handleSendMessage) {
                let empty = messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                MIcon("send", size: 18, color: AppColors.background)
                    .frame(width: 36, height: 36)
                    .background(Circle().fill(empty ? AppColors.mutedText : AppColors.live))
            }
            .buttonStyle(.plain)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isMessageFieldFocused = true
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(spacing: 14) {
            Button {
                openInSpotifyApp()
            } label: {
                HStack(spacing: 8) {
                    MIcon("spotify", size: 16, color: AppColors.secondaryText)
                    Text("Open in Spotify")
                        .font(AppFonts.subheadline())
                        .foregroundColor(AppColors.secondaryText)
                }
            }
            .buttonStyle(.plain)

            Button {
                onHideTrack()
                dismiss()
            } label: {
                Text("Hide this song")
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.mutedText)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 6)
    }

    // MARK: - Actions

    private func handlePlay() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        guard spotifyAuth.isAuthorized else {
            openInSpotifyApp()
            return
        }
        playState = .starting
        status = nil
        Task {
            do {
                try await SpotifyService.shared.playTrack(id: track.id)
                playState = .playing
                show(Status(text: "Now playing on your Spotify.", kind: .success))
            } catch SpotifyAPIError.noActiveDevice {
                // Nothing is open to play on: hand over to the Spotify app.
                playState = .idle
                openInSpotifyApp()
            } catch SpotifyAPIError.insufficientScope {
                playState = .idle
                show(Status(text: "Reconnect Spotify to control playback.", kind: .reconnect), sticky: true)
            } catch {
                playState = .idle
                show(Status(text: "Couldn’t reach Spotify. Try again.", kind: .info))
            }
        }
    }

    private func handleQueue() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard spotifyAuth.isAuthorized else {
            show(Status(text: "Connect Spotify in Settings to use the queue.", kind: .info))
            return
        }
        isQueueing = true
        Task {
            defer { isQueueing = false }
            do {
                try await SpotifyService.shared.addToQueue(trackId: track.id)
                show(Status(text: "Added to your queue.", kind: .success))
            } catch SpotifyAPIError.noActiveDevice {
                show(Status(text: "Open Spotify and play something first.", kind: .info))
            } catch SpotifyAPIError.insufficientScope {
                show(Status(text: "Reconnect Spotify to use the queue.", kind: .reconnect), sticky: true)
            } catch {
                show(Status(text: "Couldn’t reach Spotify. Try again.", kind: .info))
            }
        }
    }

    private func handleSave() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        guard spotifyAuth.isAuthorized else {
            show(Status(text: "Connect Spotify in Settings to save songs.", kind: .info))
            return
        }
        let target = !isSaved
        isSaving = true
        Task {
            defer { isSaving = false }
            do {
                try await SpotifyService.shared.setTrackSaved(id: track.id, saved: target)
                isSaved = target
                show(Status(text: target ? "Saved to your Liked Songs." : "Removed from your Liked Songs.", kind: .success))
            } catch SpotifyAPIError.insufficientScope {
                show(Status(text: "Reconnect Spotify to save songs.", kind: .reconnect), sticky: true)
            } catch {
                show(Status(text: "Couldn’t reach Spotify. Try again.", kind: .info))
            }
        }
    }

    private func loadSavedState() async {
        guard spotifyAuth.isAuthorized, !isRunningInPreview else { return }
        // Best effort: an older login without the library scope just shows "Save".
        if let saved = try? await SpotifyService.shared.isTrackSaved(id: track.id) {
            isSaved = saved
        }
    }

    private func handleLike() {
        guard !hasLiked else { return }
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        showLikeBurst = true
        likeBurst += 1
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            showLikeBurst = false
        }
        onLike()
    }

    private func handleMessageAction() {
        if hasMessaged {
            onOpenChat()
            return
        }
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
        isMessageFieldFocused = false
    }

    private func openInSpotifyApp() {
        openURL(spotifyDeepLink) { success in
            if success {
                playState = .opened
            } else {
                openURL(spotifyWebURL)
                playState = .opened
            }
        }
    }

    /// Shows a status line; non-sticky ones fade after a few seconds.
    private func show(_ newStatus: Status, sticky: Bool = false) {
        status = newStatus
        statusToken += 1
        guard !sticky else { return }
        let token = statusToken
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            if statusToken == token { status = nil }
        }
    }

    // MARK: - Helpers

    private var trackTitle: String {
        let t = track.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return t.isEmpty ? "Unknown track" : t
    }

    private var trackArtist: String {
        let a = track.artist.trimmingCharacters(in: .whitespacesAndNewlines)
        return a.isEmpty ? "Unknown artist" : a
    }

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#Preview {
    Color.black
        .sheet(isPresented: .constant(true)) {
            DiscoverTrackSheet(
                broadcast: DiscoverBroadcast(
                    id: "preview",
                    user: DiscoverUser(
                        id: "u1", firstName: "Lena", lastName: "M.", age: 27, city: "Zürich",
                        gender: nil, countryCode: "CH", heroPhotoURL: nil, profilePhotoURL: nil, photoURLs: []
                    ),
                    track: DiscoverTrack(
                        id: "3n3Ppam7vgaVa1iaRUc9Lp",
                        title: "Mr. Brightside",
                        artist: "The Killers",
                        album: "Hot Fuss",
                        artworkURL: nil,
                        spotifyTrackURL: nil
                    ),
                    broadcastedAt: Date(),
                    location: nil,
                    distanceMeters: 1200
                ),
                onLike: {}, onMessage: { _ in }, onOpenChat: {}, onViewProfile: {}, onHideTrack: {}
            )
            .environmentObject(SpotifyAuthManager.shared)
        }
}
