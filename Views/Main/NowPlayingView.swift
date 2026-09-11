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
            // Playing: the cover in the middle, the ripple around it while
            // live, the song in serif underneath.
            VStack(spacing: 0) {
                HStack {
                    Text("Live")
                        .font(.system(size: 20, weight: .heavy))
                        .foregroundColor(AppColors.primaryText)
                    Spacer()
                    if broadcast.isBroadcasting {
                        HStack(spacing: 6) {
                            RippleMark(size: 10, rings: 0)
                            Text("LIVE")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundColor(AppColors.live)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(AppColors.live.opacity(0.16)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 4)

                if let err = vm.errorMessage, !err.isEmpty {
                    Text(err)
                        .font(AppFonts.caption())
                        .foregroundColor(AppColors.secondaryText)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                Spacer(minLength: 12)

                ZStack {
                    if broadcast.isBroadcasting {
                        LiveRipple(size: 300, color: AppColors.live)
                            .opacity(0.8)
                    }
                    CompactArtwork(track: track)
                        .frame(width: 240, height: 240)
                        .shadow(color: .black.opacity(0.5), radius: 30, y: 20)
                }
                .frame(height: 300)

                VStack(spacing: 4) {
                    Text(track.title)
                        .font(AppFonts.song(size: 34))
                        .foregroundColor(AppColors.primaryText)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.7)
                    Text(track.artist)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppColors.secondaryText)
                        .lineLimit(1)
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

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
                    .padding(.top, 18)
                }

                HStack(spacing: 0) {
                    Button(action: {
                        Task { await vm.toggleShuffle() }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }) {
                        MIcon("shuffle", size: 20, color: vm.isShuffling ? AppColors.live : AppColors.mutedText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(vm.isShuffling ? "Shuffle on" : "Shuffle off")

                    Spacer()

                    Button(action: {
                        Task { await vm.previous() }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        MIcon("prev", size: 30)
                            .frame(width: 52, height: 52)
                    }
                    .disabled(vm.isLoading)
                    .accessibilityLabel("Previous track")

                    Button(action: {
                        Task { await vm.togglePlayPause() }
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    }) {
                        ZStack {
                            Circle()
                                .fill(AppColors.primaryText)
                                .frame(width: 72, height: 72)
                            MIcon(vm.isPlaying ? "pause" : "play", size: 30, color: AppColors.background)
                                .offset(x: vm.isPlaying ? 0 : 2)
                        }
                    }
                    .buttonStyle(.pressable)
                    .disabled(vm.isLoading)
                    .padding(.horizontal, 16)
                    .accessibilityLabel(vm.isPlaying ? "Pause" : "Play")

                    Button(action: {
                        Task { await vm.next() }
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    }) {
                        MIcon("next", size: 30)
                            .frame(width: 52, height: 52)
                    }
                    .disabled(vm.isLoading)
                    .accessibilityLabel("Next track")

                    Spacer()

                    Button(action: {
                        Task { await vm.cycleRepeatMode() }
                        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                    }) {
                        MIcon("repeat", size: 20, color: vm.repeatMode != .off ? AppColors.live : AppColors.mutedText)
                            .frame(width: 44, height: 44)
                    }
                    .accessibilityLabel(repeatAccessibilityLabel)
                }
                .padding(.horizontal, 28)
                .padding(.top, 18)

                Spacer(minLength: 12)

                CompactBroadcastToggle(hasTrack: true)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
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
                            .font(.system(size: 16, weight: .medium))
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
                                .font(.system(size: 17, weight: .bold))
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
                        .font(.system(size: 26, weight: .bold))
                        .foregroundColor(.white)

                    Text("Connect your Spotify account to see\nwhat's playing and go live nearby.")
                        .font(.system(size: 16, weight: .medium))
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
                            .font(.system(size: 17, weight: .bold))
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
            // The mark: breathing while live, still otherwise.
            if broadcast.isBroadcasting {
                LiveRipple(size: 26)
            } else {
                RippleMark(size: 18, color: AppColors.mutedText, rings: 1)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(broadcast.isBroadcasting ? "Sharing nearby" : "Go live nearby")
                    .font(AppFonts.subheadline())
                    .foregroundColor(.white.opacity(hasTrack ? 0.9 : 0.5))

                if let hint {
                    Text(hint)
                        .font(.system(size: 11, weight: .medium))
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
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.85))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 12, weight: .semibold))
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
                RemoteImage(url: url, size: 260) { phase in
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
                // 0…1, and never NaN when a track has no duration yet.
                let fraction: CGFloat = durationMs > 0
                    ? min(1, max(0, CGFloat(localProgress) / CGFloat(durationMs)))
                    : 0
                let filled = geometry.size.width * fraction

                ZStack(alignment: .leading) {
                    // Background track
                    Capsule()
                        .fill(Color.white.opacity(0.25))
                        .frame(height: 4)

                    // Progress track
                    Capsule()
                        .fill(Color.white)
                        .frame(width: filled, height: 4)

                    // Thumb (only visible when scrubbing)
                    if isScrubbing {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 14, height: 14)
                            .offset(x: filled - 7)
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .monospacedDigit()

                Spacer()

                Text(format(ms: Int(isScrubbing ? localProgress : Double(progressMs)), showRemaining: showRemaining))
                    .font(.system(size: 12, weight: .medium))
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
    /// Creating a CIContext costs tens of milliseconds; one is enough.
    nonisolated(unsafe) private static let averageColorContext = CIContext(options: [.workingColorSpace: kCFNull as Any])

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
                let context = UIImage.averageColorContext
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
