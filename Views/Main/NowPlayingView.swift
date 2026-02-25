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

            // ✨ Broadcast edge glow effect
            if showBroadcastGlow {
                EdgeGlowEffect()
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .top) {
            // Custom navigation bar (only show chevron when music is playing)
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
            // Update dominant color when track changes
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
            // ✅ Playing state - full immersive view
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60) // Space for custom nav bar
                
                // Compact Broadcast Toggle
                CompactBroadcastToggle(hasTrack: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // Error message if any
                if let err = vm.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                // Large artwork - MAIN focal point
                SpotifyArtwork(track: track)
                    .padding(.horizontal, 28)
                    .padding(.bottom, 32)

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
                .padding(.bottom, 28)

                // Progress bar
                if let durationMs = track.durationMs {
                    SpotifyProgressBar(
                        progressMs: vm.progressMs,
                        durationMs: durationMs,
                        isScrubbing: $vm.isScrubbing,
                        onSeek: { newProgress in
                            Task { await vm.seek(to: newProgress) }
                        }
                    )
                    .padding(.horizontal, 28)
                    .padding(.bottom, 16)
                }

                // Main playback controls - Spotify style
                SpotifyControls(
                    isPlaying: vm.isPlaying,
                    isBusy: vm.isLoading,
                    onPrevious: { Task { await vm.previous() } },
                    onToggle: { Task { await vm.togglePlayPause() } },
                    onNext: { Task { await vm.next() } }
                )
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

                // Extra controls (shuffle, open Spotify, repeat)
                HStack(spacing: 0) {
                    Button(action: {
                        Task { await vm.toggleShuffle() }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }) {
                        Image(systemName: "shuffle")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(vm.isShuffling ? Color(red: 0.2, green: 0.85, blue: 0.4) : .white.opacity(0.6))
                            .frame(width: 50, height: 50)
                    }
                    
                    Spacer()
                    
                    // Open in Spotify button (subtle)
                    Button(action: {
                        openSpotifyLibrary()
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }) {
                        Image(systemName: "arrow.up.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white.opacity(0.4))
                            .frame(width: 36, height: 36)
                            .background(
                                Circle()
                                    .fill(Color.white.opacity(0.06))
                            )
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        Task { await vm.cycleRepeatMode() }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }) {
                        let iconName: String = {
                            switch vm.repeatMode {
                            case .off: return "repeat"
                            case .context: return "repeat"
                            case .track: return "repeat.1"
                            }
                        }()
                        
                        Image(systemName: iconName)
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(vm.repeatMode != .off ? Color(red: 0.2, green: 0.85, blue: 0.4) : .white.opacity(0.6))
                            .frame(width: 50, height: 50)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 24)

                Spacer()
            }
        } else {
            // ✅ Empty state - nothing playing
            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60) // Space for custom nav bar
                
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
                // Make color darker and more saturated for better background
                var hue: CGFloat = 0
                var saturation: CGFloat = 0
                var brightness: CGFloat = 0
                var alpha: CGFloat = 0
                
                color.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
                
                // Darken and boost saturation
                let adjustedColor = UIColor(
                    hue: hue,
                    saturation: min(saturation * 1.2, 1.0),
                    brightness: min(brightness * 0.4, 0.5), // Much darker
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
            // Indicator dot
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

// MARK: - Spotify Artwork

private struct SpotifyArtwork: View {
    let track: Track

    var body: some View {
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
                        Rectangle()
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 60, weight: .thin))
                                    .foregroundColor(.white.opacity(0.3))
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundColor(.white.opacity(0.3))
                    )
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: Color.black.opacity(0.6), radius: 30, x: 0, y: 15)
    }
}

// MARK: - Spotify Progress Bar

private struct SpotifyProgressBar: View {
    let progressMs: Int
    let durationMs: Int
    @Binding var isScrubbing: Bool
    let onSeek: (Int) -> Void

    @State private var localProgress: Double = 0
    @State private var showRemaining: Bool = false

    private func format(ms: Int, showRemaining: Bool = false) -> String {
        var value = ms
        if showRemaining {
            value = max(durationMs - ms, 0)
        }
        let totalSeconds = max(value / 1000, 0)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        let prefix = showRemaining ? "-" : ""
        return String(format: "%@%d:%02d", prefix, minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 6) {
            // Custom slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 4)

                    // Progress track
                    Capsule()
                        .fill(Color.white)
                        .frame(
                            width: max(0, geometry.size.width * CGFloat(localProgress) / CGFloat(durationMs)),
                            height: 4
                        )

                    // Thumb (only visible when scrubbing)
                    if isScrubbing {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .offset(x: max(0, geometry.size.width * CGFloat(localProgress) / CGFloat(durationMs)) - 7)
                    }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            if !isScrubbing {
                                isScrubbing = true
                                localProgress = Double(progressMs)
                            }
                            let newProgress = Double(durationMs) * Double(value.location.x / geometry.size.width)
                            localProgress = min(max(newProgress, 0), Double(durationMs))
                        }
                        .onEnded { _ in
                            isScrubbing = false
                            onSeek(Int(localProgress))
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }
                )
            }
            .frame(height: 20)
            .onAppear {
                localProgress = Double(progressMs)
            }
            .onChange(of: progressMs) { _, newValue in
                if !isScrubbing {
                    localProgress = Double(newValue)
                }
            }

            // Time labels
            HStack {
                Text(format(ms: Int(isScrubbing ? localProgress : Double(progressMs))))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .monospacedDigit()

                Spacer()

                Text(format(ms: Int(isScrubbing ? localProgress : Double(progressMs)), showRemaining: showRemaining))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .monospacedDigit()
                    .onTapGesture {
                        showRemaining.toggle()
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }
            }
        }
    }
}

// MARK: - Spotify Controls

private struct SpotifyControls: View {
    let isPlaying: Bool
    let isBusy: Bool
    let onPrevious: () -> Void
    let onToggle: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Previous
            Button(action: {
                onPrevious()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.4 : 1.0)

            Spacer()

            // Play/Pause - BIG white circle
            Button(action: {
                onToggle()
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 68, height: 68)

                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.black)
                        .offset(x: isPlaying ? 0 : 2)
                }
            }
            .disabled(isBusy)
            .opacity(isBusy ? 0.6 : 1.0)

            Spacer()

            // Next
            Button(action: {
                onNext()
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(width: 80, height: 80)
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
            // Top edge
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 2)
            .frame(maxHeight: .infinity, alignment: .top)

            // Leading edge
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 2)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing edge
            LinearGradient(
                colors: [Color.clear, Color(red: 0.2, green: 0.85, blue: 0.4).opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 2)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Bottom edge
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
