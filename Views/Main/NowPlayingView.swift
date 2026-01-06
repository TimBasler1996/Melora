//
//  NowPlayingView.swift
//  SocialSound
//
//  Created by Tim Basler on 05.01.2026.
//

import SwiftUI

struct NowPlayingView: View {

    @EnvironmentObject private var currentUserStore: CurrentUserStore
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
                ToolbarItem(placement: .topBarTrailing) {
                    if let user = currentUserStore.user {
                        LikesInboxButton(user: user)
                    }
                }
            }
        }
        .onAppear { vm.start() }
        .onDisappear { vm.stop() }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.handleWillEnterForeground()
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 14) {

            if let err = vm.errorMessage, !err.isEmpty {
                InfoBanner(text: err)
            }

            if let track = vm.currentTrack {
                TrackCard(track: track)

                ControlsRow(
                    isPlaying: vm.isPlaying,
                    isBusy: vm.isLoading,
                    onPrevious: { Task { await vm.previous() } },
                    onToggle: { Task { await vm.togglePlayPause() } },
                    onNext: { Task { await vm.next() } }
                )
            } else {
                EmptyStateCard()
            }

            Spacer()
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 12)
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

