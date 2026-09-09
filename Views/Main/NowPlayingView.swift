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
        NavigationStack {
            ZStack {
                // Dynamic gradient background based on album artwork (intended hero treatment)
                ZStack {
                    dominantColor
                        .ignoresSafeArea()

                    LinearGradient(
                        colors: [
                            dominantColor.opacity(0.8),
                            AppColors.background
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
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Now Playing")
                        .font(AppFonts.headline())
                        .foregroundColor(AppColors.primaryText)
                }

                ToolbarItem(placement: .topBarTrailing) {
                    if let user = currentUserStore.user {
                        LikesInboxButton(user: user)
                    }
                }
            }
        }
        .onAppear {
            // Silent refresh only — the disconnected state below offers an
            // explicit Connect button instead of auto-opening the login sheet.
            spotifyAuth.refreshAuthorizationSilently()
            vm.start()
        }
        .onDisappear {
            vm.stop()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // Resume polling when returning to the foreground. `start()` already
            // refreshes now-playing and player state once.
            vm.start()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            // Stop hitting the Spotify API while the app is backgrounded.
            vm.stop()
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
        if !spotifyAuth.isAuthorized && vm.currentTrack == nil {
            spotifyDisconnectedState
        } else if let track = vm.currentTrack {
            // ✅ Playing state - compact Melora view
            VStack(spacing: 0) {
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

                Spacer()

                // Compact music card: artwork left, info + controls right
                VStack(spacing: 20) {
                    HStack(spacing: 16) {
                        // Compact artwork
                        CompactArtwork(track: track)
                            .frame(width: 140, height: 140)

                        // Track info
                        VStack(alignment: .leading, spacing: 6) {
                            Text(track.title)
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .minimumScaleFactor(0.8)

                            Text(track.artist)
                                .font(AppFonts.subheadline())
                                .foregroundColor(.white.opacity(0.7))
                                .lineLimit(1)

                            if let album = track.album, !album.isEmpty {
                                Text(album)
                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.4))
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 24)

                    // Thin progress bar
                    if let durationMs = track.durationMs {
                        SpotifyProgressBar(
                            progressMs: vm.progressMs,
                            durationMs: durationMs,
                            isScrubbing: $vm.isScrubbing,
                            onSeek: { newProgress in
                                Task { await vm.seek(to: newProgress) }
                            }
                        )
                        .padding(.horizontal, 24)
                    }

                    // Compact playback controls
                    HStack(spacing: 0) {
                        // Shuffle
                        Button(action: {
                            Task { await vm.toggleShuffle() }
                            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                        }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(vm.isShuffling ? AppColors.live : .white.opacity(0.5))
                                .frame(width: 40, height: 40)
                        }
                        .accessibilityLabel(vm.isShuffling ? "Shuffle on" : "Shuffle off")

                        Spacer()

                        // Previous
                        Button(action: {
                            Task { await vm.previous() }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                        }
                        .disabled(vm.isLoading)
                        .accessibilityLabel("Previous track")

                        // Play/Pause
                        Button(action: {
                            Task { await vm.togglePlayPause() }
                            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 48, height: 48)

                                Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundColor(.black)
                                    .offset(x: vm.isPlaying ? 0 : 2)
                            }
                        }
                        .disabled(vm.isLoading)
                        .padding(.horizontal, 8)
                        .accessibilityLabel(vm.isPlaying ? "Pause" : "Play")

                        // Next
                        Button(action: {
                            Task { await vm.next() }
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 52, height: 52)
                        }
                        .disabled(vm.isLoading)
                        .accessibilityLabel("Next track")

                        Spacer()

                        // Repeat
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
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(vm.repeatMode != .off ? AppColors.live : .white.opacity(0.5))
                                .frame(width: 40, height: 40)
                        }
                        .accessibilityLabel(repeatAccessibilityLabel)
                    }
                    .padding(.horizontal, 24)
                }
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(AppColors.surface)
                )
                .padding(.horizontal, 16)

                Spacer()
            }
        } else {
            // ✅ Empty state - nothing playing
            VStack(spacing: 0) {
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
                            .font(AppFonts.largeTitle())
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

    /// Shown when Spotify isn't connected (first run, token expired, or the
    /// user disconnected in settings). Explains why nothing is playing and
    /// offers an explicit reconnect instead of a silent dead end.
    private var spotifyDisconnectedState: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                Image(systemName: "bolt.slash.fill")
                    .font(.system(size: 56, weight: .thin))
                    .foregroundColor(.white.opacity(0.4))

                VStack(spacing: 12) {
                    Text("Spotify Not Connected")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("Connect your Spotify account to see\nwhat's playing and go live nearby.")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Button(action: {
                    spotifyAuth.ensureAuthorized()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "link")
                            .font(.system(size: 15, weight: .bold))

                        Text("Connect Spotify")
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                    }
                    .foregroundColor(.black)
                    .padding(.horizontal, 36)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(AppColors.live)
                    )
                }
                .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }

    private var repeatAccessibilityLabel: String {
        switch vm.repeatMode {
        case .off: return "Repeat off"
        case .context: return "Repeat all"
        case .track: return "Repeat one"
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
        VStack(spacing: 0) {
            toggleRow
            if broadcast.isBroadcasting && locationDenied {
                locationWarning
            }
        }
    }

    private var toggleRow: some View {
        HStack(spacing: 12) {
            // Indicator dot
            Circle()
                .fill(broadcast.isBroadcasting ? AppColors.live : AppColors.mutedText)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle()
                        .fill(broadcast.isBroadcasting ? AppColors.live : Color.clear)
                        .scaleEffect(broadcast.isBroadcasting ? 2.0 : 1.0)
                        .opacity(broadcast.isBroadcasting ? 0.3 : 0)
                        .animation(
                            broadcast.isBroadcasting ?
                            .easeInOut(duration: 1.5).repeatForever(autoreverses: false) : .default,
                            value: broadcast.isBroadcasting
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(broadcast.isBroadcasting ? "You’re live nearby" : "Go live nearby")
                    .font(AppFonts.subheadline())
                    .foregroundColor(.white.opacity(hasTrack ? 0.9 : 0.5))

                if let hint {
                    Text(hint)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { broadcast.isBroadcasting },
                set: { newValue in
                    Task {
                        if newValue {
                            // First go-live is where location makes sense:
                            // it is what puts you on other people's Discover.
                            locationService.requestAuthorizationIfNeeded()
                            broadcast.attachLocationService(locationService)
                        }
                        await broadcast.setBroadcasting(newValue)
                    }
                }
            ))
            .labelsHidden()
            .tint(AppColors.live)
            .disabled(!spotifyAuth.isAuthorized || (!hasTrack && !broadcast.isBroadcasting))
            .opacity(hasTrack ? 1.0 : 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(AppColors.surface)
        )
    }

    private var locationDenied: Bool {
        switch locationService.authorizationStatus {
        case .denied, .restricted: return true
        default: return false
        }
    }

    /// Why the toggle can't be used right now; nil when it can.
    private var hint: String? {
        if broadcast.isBroadcasting {
            return locationDenied ? nil : "People nearby can see what you’re playing"
        }
        if !spotifyAuth.isAuthorized { return "Connect Spotify to go live" }
        if !hasTrack { return "Play something on Spotify to go live" }
        return nil
    }

    private var locationWarning: some View {
        HStack(spacing: 10) {
            Image(systemName: "location.slash")
                .foregroundColor(AppColors.primary)
            Text("Location is off, so nobody nearby can find you. Turn it on in Settings.")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppColors.surface)
        )
        .padding(.top, 8)
    }
}

// MARK: - Compact Artwork

private struct CompactArtwork: View {
    let track: Track

    var body: some View {
        Group {
            if let url = track.artworkURL {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(AppColors.surface)
                            .overlay(ProgressView().tint(.white))
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
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
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.3), radius: 12, x: 0, y: 6)
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(AppColors.surface)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 36, weight: .thin))
                    .foregroundColor(.white.opacity(0.3))
            )
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

// MARK: - Edge Glow Effect

private struct EdgeGlowEffect: View {
    var body: some View {
        ZStack {
            // Top edge
            LinearGradient(
                colors: [AppColors.live.opacity(0.8), Color.clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 2)
            .frame(maxHeight: .infinity, alignment: .top)

            // Leading edge
            LinearGradient(
                colors: [AppColors.live.opacity(0.8), Color.clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 2)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Trailing edge
            LinearGradient(
                colors: [Color.clear, AppColors.live.opacity(0.8)],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 2)
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Bottom edge
            LinearGradient(
                colors: [Color.clear, AppColors.live.opacity(0.8)],
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
