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
    @State private var dominantColor: Color = Color(red: 0.2, green: 0.2, blue: 0.3)
    @State private var showBroadcastGlow: Bool = false

    var body: some View {
        ZStack {
            // Dynamic gradient background based on album artwork
            ZStack {
                dominantColor
                    .ignoresSafeArea()

                LinearGradient(
                    colors: [
                        dominantColor.opacity(0.8),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            }
            .animation(.easeInOut(duration: 1.0), value: dominantColor)

            content

            if showBroadcastGlow {
                EdgeGlowEffect()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            HStack {
                if vm.currentTrack != nil {
                    Button {
                        openSpotifyLibrary()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }

                Spacer()

                Text("Now Playing")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Spacer()

                if let user = currentUserStore.user {
                    LikesInboxButton(user: user)
                } else {
                    Color.clear.frame(width: 44, height: 44)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
        }
        .onAppear {
            spotifyAuth.ensureAuthorized()
            vm.start()
        }
        .onDisappear {
            vm.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            vm.handleWillEnterForeground()
        }
        .onChange(of: vm.currentTrack) { _, newTrack in
            broadcast.updateCurrentTrack(newTrack)
            if let artworkURL = newTrack?.artworkURL {
                Task {
                    await extractDominantColor(from: artworkURL)
                }
            } else {
                dominantColor = Color(red: 0.2, green: 0.2, blue: 0.3)
            }
        }
        .onChange(of: broadcast.isBroadcasting) { _, newValue in
            if newValue {
                triggerBroadcastFeedback()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if let track = vm.currentTrack {
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                CompactBroadcastToggle(hasTrack: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                if let err = vm.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                // Album artwork with optional LIVE overlay
                BroadcastArtwork(track: track, isBroadcasting: broadcast.isBroadcasting)
                    .padding(.horizontal, 28)

                // Simple progress indicator
                if let durationMs = track.durationMs {
                    SimpleProgressBar(
                        progressMs: vm.progressMs,
                        durationMs: durationMs
                    )
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                }

                // Track info
                VStack(spacing: 6) {
                    Text(track.title)
                        .font(.system(size: 26, weight: .bold, design: .default))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(track.artist)
                        .font(.system(size: 16, weight: .semibold, design: .default))
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 32)
                .padding(.top, 24)
                .padding(.bottom, 28)

                // Playback controls
                PlaybackControls(
                    isPlaying: vm.isPlaying,
                    isBusy: vm.isLoading,
                    onPrevious: { Task { await vm.previous() } },
                    onToggle: { Task { await vm.togglePlayPause() } },
                    onNext: { Task { await vm.next() } }
                )
                .padding(.horizontal, 40)
                .padding(.bottom, 20)

                // Open in Spotify
                Button {
                    openSpotifyLibrary()
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 12, weight: .semibold))
                        Text("Open in Spotify")
                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                    }
                    .foregroundColor(.white.opacity(0.4))
                }
                .padding(.bottom, 24)

                Spacer()
            }
        } else {
            // Empty state
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                CompactBroadcastToggle(hasTrack: false)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)

                Spacer()

                VStack(spacing: 24) {
                    Image(systemName: "music.note")
                        .font(.system(size: 64, weight: .thin))
                        .foregroundColor(.white.opacity(0.4))

                    VStack(spacing: 12) {
                        Text("Nothing Playing")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundColor(.white)

                        Text("Start playing music on Spotify\nto see it here")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                    }

                    Button(action: {
                        openSpotify()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.up.right")
                                .font(.system(size: 15, weight: .bold))

                            Text("Open Spotify")
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 16)
                        .background(
                            Capsule()
                                .fill(Color.white)
                        )
                    }
                    .padding(.top, 8)
                }

                Spacer()
                Spacer()
            }
        }
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

    private func openSpotify() {
        let appURL = URL(string: "spotify:")!
        let webURL = URL(string: "https://open.spotify.com")!

        openURL(appURL) { success in
            if !success {
                openURL(webURL)
            }
        }
    }

    private func extractDominantColor(from url: URL) async {
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let uiImage = UIImage(data: data) else {
            return
        }

        if let color = await uiImage.dominantColor() {
            await MainActor.run {
                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0

                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)

                let adjustedColor = UIColor(
                    hue: hue,
                    saturation: min(saturation * 1.2, 1.0),
                    brightness: min(brightness * 0.4, 0.5),
                    alpha: 1.0
                )

                dominantColor = Color(adjustedColor)
            }
        }
    }

    private func triggerBroadcastFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        withAnimation(.easeInOut(duration: 0.3)) {
            showBroadcastGlow = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            withAnimation(.easeOut(duration: 0.3)) {
                showBroadcastGlow = false
            }
        }
    }
}

// MARK: - Compact Broadcast Toggle

private struct CompactBroadcastToggle: View {
    let hasTrack: Bool

    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @EnvironmentObject private var locationService: LocationService

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(broadcast.isBroadcasting ? Color(red: 0.2, green: 0.85, blue: 0.4) : Color.white.opacity(0.3))
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(broadcast.isBroadcasting ? Color(red: 0.2, green: 0.85, blue: 0.4) : Color.clear)
                        .scaleEffect(broadcast.isBroadcasting ? 2.0 : 1.0)
                        .opacity(broadcast.isBroadcasting ? 0.3 : 0)
                        .animation(
                            broadcast.isBroadcasting ?
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: false) : .default,
                            value: broadcast.isBroadcasting
                        )
                )

            Text(broadcast.isBroadcasting ? "Broadcasting nearby" : "Go live nearby")
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(hasTrack ? 0.9 : 0.5))

            Spacer()

            Toggle("", isOn: Binding(
                get: { broadcast.isBroadcasting },
                set: { newValue in
                    Task {
                        if newValue {
                            locationService.requestAuthorizationIfNeeded()
                            broadcast.attachLocationService(locationService)
                        }
                        await broadcast.setBroadcasting(newValue)
                    }
                }
            ))
            .labelsHidden()
            .tint(Color(red: 0.2, green: 0.85, blue: 0.4))
            .disabled(!spotifyAuth.isAuthorized || (!hasTrack && !broadcast.isBroadcasting))
            .opacity(hasTrack ? 1.0 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(Color.white.opacity(0.08))
        )
    }
}

// MARK: - Broadcast Artwork (with LIVE badge)

private struct BroadcastArtwork: View {
    let track: Track
    let isBroadcasting: Bool

    private let liveGreen = Color(red: 0.2, green: 0.85, blue: 0.4)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Group {
                if let url = track.artworkURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(Color.white.opacity(0.08))
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                        .scaleEffect(1.2)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                        case .failure:
                            artworkPlaceholder
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    artworkPlaceholder
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isBroadcasting ? liveGreen : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.5), radius: 24, x: 0, y: 12)

            // LIVE badge
            if isBroadcasting {
                Text("LIVE")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(liveGreen))
                    .padding(10)
            }
        }
    }

    private var artworkPlaceholder: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 60, weight: .thin))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}

// MARK: - Simple Progress Bar (no scrubbing)

private struct SimpleProgressBar: View {
    let progressMs: Int
    let durationMs: Int

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(height: 3)
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: max(0, geo.size.width * progress), height: 3)
                    .animation(.linear(duration: 0.3), value: progressMs)
            }
        }
        .frame(height: 3)
    }

    private var progress: CGFloat {
        guard durationMs > 0 else { return 0 }
        return min(CGFloat(progressMs) / CGFloat(durationMs), 1.0)
    }
}

// MARK: - Playback Controls

private struct PlaybackControls: View {
    let isPlaying: Bool
    let isBusy: Bool
    let onPrevious: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Button(action: {
                onPrevious()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 60, height: 60)
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.4 : 1.0)

            Spacer()

            Button(action: {
                onToggle()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 38, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 72, height: 72)
                    .offset(x: isPlaying ? 0 : 2)
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.6 : 1.0)

            Spacer()

            Button(action: {
                onNext()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(.white.opacity(0.7))
                    .frame(width: 60, height: 60)
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.4 : 1.0)
        }
    }
}

// MARK: - Edge Glow Effect

private struct EdgeGlowEffect: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 2)
            .frame(maxHeight: .infinity, alignment: .top)

            LinearGradient(
                colors: [Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 2)
            .frame(maxWidth: .infinity, alignment: .leading)

            LinearGradient(
                colors: [Color.clear, Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 2)
            .frame(maxWidth: .infinity, alignment: .trailing)

            LinearGradient(
                colors: [Color.clear, Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 2)
            .frame(maxHeight: .infinity, alignment: .bottom)
        }
    }
}

// MARK: - UIImage Extension for Dominant Color

extension UIImage {
    func dominantColor() async -> UIColor? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                guard let inputImage = CIImage(image: self) else {
                    continuation.resume(returning: nil)
                    return
                }

                let extentVector = CIVector(
                    x: inputImage.extent.origin.x,
                    y: inputImage.extent.origin.y,
                    z: inputImage.extent.size.width,
                    w: inputImage.extent.size.height
                )

                guard let filter = CIFilter(
                    name: "CIAreaAverage",
                    parameters: [kCIInputImageKey: inputImage, kCIInputExtentKey: extentVector]
                ) else {
                    continuation.resume(returning: nil)
                    return
                }

                guard let outputImage = filter.outputImage else {
                    continuation.resume(returning: nil)
                    return
                }

                var bitmap = [UInt8](repeating: 0, count: 4)
                let context = CIContext(options: [.workingColorSpace: kCFNull as Any])
                context.render(
                    outputImage,
                    toBitmap: &bitmap,
                    rowBytes: 4,
                    bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
                    format: .RGBA8,
                    colorSpace: nil
                )

                let color = UIColor(
                    red: CGFloat(bitmap[0]) / 255,
                    green: CGFloat(bitmap[1]) / 255,
                    blue: CGFloat(bitmap[2]) / 255,
                    alpha: CGFloat(bitmap[3]) / 255
                )

                continuation.resume(returning: color)
            }
        }
    }
}
