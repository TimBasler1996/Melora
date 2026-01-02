import SwiftUI

struct NowPlayingView: View {

    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager
    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var locationService: LocationService

    @StateObject private var vm = NowPlayingViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 16) {

                header

                if !spotifyAuth.isAuthorized {
                    connectCard
                } else {
                    contentCard
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.top, 20)
            .padding(.bottom, 14)
        }
        .onAppear {
            // ✅ richtige Methode in deinem LocationService
            locationService.requestAuthorizationIfNeeded()

            if spotifyAuth.isAuthorized {
                vm.fetchCurrentTrack()
            }
        }
        .onChange(of: spotifyAuth.isAuthorized) { _ in
            if spotifyAuth.isAuthorized {
                vm.fetchCurrentTrack()
            } else {
                vm.currentTrack = nil
            }
        }
    }

    // MARK: - UI

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Now Playing")
                .font(AppFonts.title())
                .foregroundColor(.white)

            Text(spotifyAuth.isAuthorized ? "Connected to Spotify" : "Not connected")
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var connectCard: some View {
        VStack(spacing: 12) {
            Text("Connect Spotify")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.primaryText)

            Text("To see your current track and broadcast it nearby.")
                .font(AppFonts.body())
                .foregroundColor(AppColors.mutedText)
                .multilineTextAlignment(.center)

            Button {
                // ✅ public API (startAuthFlow ist private)
                spotifyAuth.ensureAuthorized()
            } label: {
                Text("Connect")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
        )
    }

    private var contentCard: some View {
        VStack(spacing: 14) {

            if vm.isLoading {
                ProgressView()
                    .tint(.white)
                    .padding(.top, 10)
            } else if let err = vm.errorMessage {
                Text(err)
                    .font(AppFonts.body())
                    .foregroundColor(.white)
            } else if let track = vm.currentTrack {
                trackRow(track)
            } else {
                Text("No track playing right now.")
                    .font(AppFonts.body())
                    .foregroundColor(.white.opacity(0.9))
            }

            HStack(spacing: 10) {
                Button {
                    vm.fetchCurrentTrack()
                } label: {
                    Text("Refresh")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.14))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }

                Button {
                    toggleBroadcast()
                } label: {
                    Text(broadcast.isBroadcasting ? "Stop Broadcast" : "Start Broadcast")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white.opacity(0.22))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .disabled(vm.currentTrack == nil)
                .opacity(vm.currentTrack == nil ? 0.5 : 1)
            }
        }
        .padding(AppLayout.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: AppLayout.cornerRadiusLarge, style: .continuous)
                .fill(Color.white.opacity(0.16))
        )
    }

    private func trackRow(_ track: Track) -> some View {
        HStack(spacing: 12) {

            artwork(track.artworkURL)

            VStack(alignment: .leading, spacing: 4) {
                Text(track.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.85))
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func artwork(_ url: URL?) -> some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .empty:
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.15))
                            ProgressView().tint(.white)
                        }
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFill()
                    default:
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                    }
                }
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.15))
            }
        }
        .frame(width: 64, height: 64)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Broadcast

    private func toggleBroadcast() {
        if broadcast.isBroadcasting {
            broadcast.stopBroadcasting()
            return
        }

        guard let track = vm.currentTrack else { return }
        let loc = locationService.currentLocation

        broadcast.startBroadcasting(
            currentTrack: track,
            location: loc
        )
    }
}

