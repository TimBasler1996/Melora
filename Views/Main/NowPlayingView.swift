//
//  NowPlayingView.swift
//  SocialSound
//
//  Created by Tim Basler on 05.01.2026.
//

import SwiftUI
import UIKit

struct NowPlayingView: View {

    @EnvironmentObject private var currentUserStore: CurrentUserStore
    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @Environment(\.openURL) private var openURL

    @StateObject private var vm = NowPlayingViewModel()

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
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        openSpotifyLibrary()
                    } label: {
                        Label("Your Library", systemImage: "books.vertical")
                    }
                    .buttonStyle(.plain)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let user = currentUserStore.user {
                        LikesInboxButton(user: user)
                    }
                }
            }
        }
        .onAppear {
            // keep Spotify auth “automatic”
            spotifyAuth.ensureAuthorized()
            vm.start()
        }
        .onDisappear {
            vm.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.handleWillEnterForeground()
        }
        // ✅ Auto-sync to Firestore when broadcasting
        .onChange(of: vm.currentTrack) { newTrack in
            broadcast.updateCurrentTrack(newTrack)
        }
    }

    @ViewBuilder
    private var content: some View {
        ScrollView {
            VStack(spacing: 14) {

                // ✅ Broadcast Toggle UI (back)
                BroadcastToggleCard()

                if let err = vm.errorMessage, !err.isEmpty {
                    InfoBanner(text: err)
                }

                if let track = vm.currentTrack {
                    LargeNowPlaying(
                        track: track,
                        progressMs: vm.progressMs,
                        isPlaying: vm.isPlaying,
                        onSeek: { newProgress in Task { await vm.seek(to: newProgress) } }
                    )
                    .padding(.top, 8)

                    VStack(spacing: 10) {
                        ControlsRow(
                            isPlaying: vm.isPlaying,
                            isBusy: vm.isLoading,
                            onPrevious: { Task { await vm.previous() } },
                            onToggle: { Task { await vm.togglePlayPause() } },
                            onNext: { Task { await vm.next() } }
                        )
                        PlaybackExtrasRow(
                            isShuffling: vm.isShuffling,
                            repeatMode: vm.repeatMode,
                            onToggleShuffle: { Task { await vm.toggleShuffle() } },
                            onCycleRepeat: { Task { await vm.cycleRepeatMode() } }
                        )
                    }
                } else {
                    EmptyStateCard()
                }
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.vertical, 12)
        }
        .scrollIndicators(.hidden)
    }

    private func openSpotifyLibrary() {
        let appURL = URL(string: "spotify:collection")!
        let webURL = URL(string: "https://open.spotify.com/collection")!

        openURL(appURL) { success in
            if !success {
                openURL(webURL)
            }
        }
    }
}

// MARK: - Components

private struct InfoBanner: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFonts.footnote())
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct TrackCard: View {

    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            artwork

            VStack(alignment: .leading, spacing: 6) {
                Text(track.title)
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                Text(track.artist)
                    .font(AppFonts.footnote())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)

                if let album = track.album, !album.isEmpty {
                    Text(album)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(AppColors.mutedText)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.cardBackground.opacity(0.98))
                .shadow(color: Color.black.opacity(0.12), radius: 10, x: 0, y: 8)
        )
    }

    private var artwork: some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.tintedBackground)
                            .overlay(ProgressView().tint(.white))
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 12)
                            .fill(AppColors.tintedBackground)
                            .overlay(Image(systemName: "music.note").foregroundColor(.white))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.tintedBackground)
                    .overlay(Image(systemName: "music.note").foregroundColor(.white))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct LargeNowPlaying: View {
    let track: Track
    let progressMs: Int
    let isPlaying: Bool
    let onSeek: (Int) -> Void

    @State private var isScrubbing = false
    @State private var localProgress: Double = 0
    @State private var showRemaining = false

    private func format(ms: Int, showRemaining: Bool = false, durationMs: Int? = nil) -> String {
        var value = ms
        if showRemaining, let durationMs {
            value = max(durationMs - ms, 0)
        }
        let totalSeconds = max(value / 1000, 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let prefix = showRemaining ? "-" : ""
        return String(format: "%@%d:%02d", prefix, minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 16) {
            // Big artwork with animated transition when track changes
            Group {
                if let url = track.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            ZStack { Rectangle().fill(Color.white.opacity(0.08)); ProgressView().tint(.white) }
                        case .success(let img):
                            img.resizable().scaledToFit()
                                .transition(.scale.combined(with: .opacity))
                        default:
                            ZStack { Rectangle().fill(Color.white.opacity(0.08)); Image(systemName: "music.note").foregroundColor(.white) }
                        }
                    }
                } else {
                    ZStack { Rectangle().fill(Color.white.opacity(0.08)); Image(systemName: "music.note").foregroundColor(.white) }
                }
            }
            .id(track.id) // animate on track change
            .animation(.spring(response: 0.5, dampingFraction: 0.85), value: track.id)
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 18, x: 0, y: 12)

            // Title / artist centered
            VStack(spacing: 6) {
                Text(track.title)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                Text(track.artist)
                    .font(.system(size: 15, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                    .lineLimit(1)
            }
            .padding(.top, 4)

            // Timeline with scrubbing debounce
            if let durationMs = track.durationMs {
                VStack(spacing: 8) {
                    Slider(
                        value: .init(
                            get: { isScrubbing ? localProgress : Double(progressMs) },
                            set: { newVal in
                                if !isScrubbing {
                                    isScrubbing = true
                                    localProgress = Double(progressMs)
                                }
                                localProgress = newVal
                            }
                        ),
                        in: 0...Double(durationMs)
                    )
                    .tint(.white)
                    .onChange(of: isScrubbing) { old, new in
                        // When scrubbing ends, commit seek with haptic
                        if old == true && new == false {
                            let final = Int(localProgress)
                            onSeek(final)
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                    }
                    .gesture(DragGesture(minimumDistance: 0).onEnded { _ in
                        // End scrubbing when the drag ends on the Slider
                        isScrubbing = false
                    })
                    .onAppear { localProgress = Double(progressMs) }
                    .onChange(of: progressMs) { _, newVal in
                        if !isScrubbing { localProgress = Double(newVal) }
                        if newVal >= (durationMs - 500) {
                            // Haptic when reaching end
                            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
                        }
                    }

                    HStack {
                        Text(format(ms: min(Int(isScrubbing ? localProgress : Double(progressMs)), durationMs), showRemaining: false))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .onTapGesture { showRemaining.toggle() }
                        Spacer()
                        Text(format(ms: min(Int(isScrubbing ? localProgress : Double(progressMs)), durationMs), showRemaining: showRemaining, durationMs: durationMs))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundColor(.white.opacity(0.9))
                            .onTapGesture { showRemaining.toggle() }
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.white.opacity(0.12))
        )
    }
}

private struct ControlsRow: View {

    let isPlaying: Bool
    let isBusy: Bool

    let onPrevious: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 18) {

            Button(action: onPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            Button(action: onToggle) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 64, height: 64)
                    .background(Circle().fill(Color.white.opacity(0.22)))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)

            Button(action: onNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color.white.opacity(0.18)))
            }
            .buttonStyle(.plain)
            .disabled(isBusy)
        }
        .padding(.top, 6)
    }
}

private struct PlaybackExtrasRow: View {
    let isShuffling: Bool
    let repeatMode: NowPlayingViewModel.RepeatMode
    let onToggleShuffle: () -> Void
    let onCycleRepeat: () -> Void

    var body: some View {
        HStack(spacing: 20) {
            Button(action: onToggleShuffle) {
                Image(systemName: "shuffle")
                    .symbolVariant(isShuffling ? .fill : .none)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)

            Button(action: onCycleRepeat) {
                let name: String = {
                    switch repeatMode {
                    case .off: return "repeat"
                    case .context: return "repeat"
                    case .track: return "repeat.1"
                    }
                }()
                Image(systemName: name)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(Color.white.opacity(0.16)))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 2)
    }
}

private struct EmptyStateCard: View {
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "music.note")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white.opacity(0.9))

            Text("Nothing playing")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text("Start a song on Spotify and come back here.")
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.14))
        )
    }
}
