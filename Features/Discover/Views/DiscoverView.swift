import SwiftUI
import CoreLocation

struct DiscoverView: View {

    @StateObject private var viewModel = DiscoverViewModel()

    @EnvironmentObject private var currentUserStore: CurrentUserStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var broadcast: BroadcastManager
    @EnvironmentObject private var spotifyAuth: SpotifyAuthManager

    @State private var showUserSearch = false
    /// Go live from the banner: checking Spotify and flagging the broadcast.
    @State private var goingLive = false
    @State private var showNothingPlaying = false
    @State private var expandedCardId: String?
    @State private var chatToOpen: ChatTarget?
    /// The song sheet, when a track was tapped.
    @State private var trackSheetBroadcast: DiscoverBroadcast?
    /// What to present once the song sheet has finished dismissing
    /// (profile or chat): two sheets on top of each other would fight.
    @State private var pendingAfterTrackSheet: (() -> Void)?

    /// A chat to push, with the peer so the thread can recover if the
    /// conversation was deleted meanwhile.
    private struct ChatTarget: Identifiable, Hashable {
        let conversationId: String
        let peerId: String
        var id: String { conversationId }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    goLiveBanner
                    modePickerBar
                    // The radius belongs to Nearby; people you follow show
                    // up wherever they are.
                    if viewModel.discoverMode == .nearby {
                        locationBar
                    }
                    content
                }

                if let undo = viewModel.undo {
                    undoToast(undo)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.undo)
            .melScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    MeloraWordmark(size: 26)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showUserSearch = true
                    } label: {
                        MIcon("search", size: 20)
                            .frame(width: 44, height: 44)
                            .background(Circle().fill(AppColors.surface))
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Find people")
                }
            }
            .navigationDestination(item: $chatToOpen) { target in
                ChatView(conversationId: target.conversationId, peerUserId: target.peerId)
            }
            .sheet(isPresented: $showUserSearch) {
                UserSearchView()
            }
            .sheet(item: $trackSheetBroadcast, onDismiss: {
                let next = pendingAfterTrackSheet
                pendingAfterTrackSheet = nil
                next?()
            }) { broadcast in
                trackSheet(for: broadcast)
            }
            .sheet(item: $viewModel.selectedBroadcast) { broadcast in
                NavigationStack {
                    UserProfilePreviewView(userId: broadcast.user.id)
                        .toolbar {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Close") { viewModel.selectedBroadcast = nil }
                                    .foregroundColor(.white)
                            }
                        }
                }
                .presentationDetents([.large])
            }
            .confirmationDialog(
                "Not interested?",
                isPresented: Binding(
                    get: { viewModel.dismissTarget != nil },
                    set: { isPresented in
                        if !isPresented {
                            viewModel.cancelDismiss()
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let target = viewModel.dismissTarget {
                    Button("Hide this song") {
                        viewModel.muteTrack(for: target)
                    }
                    Button("Hide \(target.user.displayName)", role: .destructive) {
                        viewModel.muteUser(for: target)
                    }
                    Button("Block \(target.user.displayName)", role: .destructive) {
                        viewModel.blockUser(for: target)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDismiss()
                }
            } message: {
                Text("Hidden songs and people can be restored in Settings.")
            }
            .alert("Nothing is playing", isPresented: $showNothingPlaying) {
                Button("Open Spotify") {
                    if let url = URL(string: "spotify:") { UIApplication.shared.open(url) }
                }
                Button("OK", role: .cancel) {}
            } message: {
                Text("Start a song on Spotify, then tap Go live.")
            }
            .onChange(of: broadcast.errorMessage) { _, message in
                // Going live happens here now, so its failures show here too.
                if let message, !message.isEmpty { viewModel.actionError = message }
            }
            .alert(
                "Couldn’t do that",
                isPresented: Binding(
                    get: { viewModel.actionError != nil },
                    set: { if !$0 { viewModel.actionError = nil } }
                )
            ) {
                Button("OK", role: .cancel) { viewModel.actionError = nil }
            } message: {
                Text(viewModel.actionError ?? "")
            }
            .onAppear {
                guard !isRunningInPreview else { return }
                // Discover is the first screen: make sure the banner knows
                // whether Spotify is connected before anyone visits Live.
                spotifyAuth.refreshAuthorizationSilently()
                locationService.requestAuthorizationIfNeeded()
                viewModel.updateCurrentLocation(locationService.currentLocationPoint)
                viewModel.startListening()
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .onChange(of: locationService.currentLocationPoint) { _, newValue in
                viewModel.updateCurrentLocation(newValue)
            }
        }
    }

    // MARK: - Top controls

    // MARK: - Go live banner

    /// The contribution action lives on the home screen: one tap from
    /// looking at people to being seen by them.
    private var goLiveBanner: some View {
        Button {
            goLive()
        } label: {
            HStack(spacing: 12) {
                if broadcast.isBroadcasting {
                    LiveRipple(size: 40)
                } else {
                    RippleMark(size: 40, color: AppColors.mutedText)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(goLiveTitle)
                        .font(.system(size: 15, weight: .heavy))
                        .foregroundColor(broadcast.isBroadcasting ? AppColors.live : AppColors.primaryText)
                        .lineLimit(1)
                    if broadcast.isBroadcasting, let track = broadcast.currentTrack {
                        (Text(track.title).font(AppFonts.song(size: 17)).foregroundColor(AppColors.primaryText)
                         + Text(track.artist.isEmpty ? "" : "  ·  \(track.artist)").font(AppFonts.footnote()).foregroundColor(AppColors.secondaryText))
                            .lineLimit(1)
                            .truncationMode(.tail)
                    } else {
                        Text(goLiveSubtitle)
                            .font(AppFonts.footnote())
                            .foregroundColor(AppColors.secondaryText)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Group {
                    if goingLive {
                        ProgressView()
                            .tint(AppColors.background)
                            .scaleEffect(0.8)
                    } else {
                        Text(broadcast.isBroadcasting ? "Manage" : "Go live")
                    }
                }
                .font(.system(size: 13, weight: .heavy))
                .foregroundColor(broadcast.isBroadcasting ? AppColors.primaryText : AppColors.background)
                .frame(minWidth: 52)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(Capsule().fill(broadcast.isBroadcasting ? AppColors.surfaceElevated : AppColors.live))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .melCard(cornerRadius: 14)
        }
        .buttonStyle(.pressable)
        .disabled(goingLive)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 4)
        .padding(.bottom, 8)
    }

    /// One tap, and you're on the map, without leaving Discover. The Live
    /// tab stays the place to manage or stop a broadcast.
    private func goLive() {
        if broadcast.isBroadcasting {
            router.goLive()
            return
        }
        guard spotifyAuth.isAuthorized else {
            spotifyAuth.ensureAuthorized()
            return
        }
        guard !goingLive else { return }
        goingLive = true
        Task {
            defer { goingLive = false }
            let state = try? await SpotifyService.shared.fetchNowPlayingState()
            guard let state, state.isPlaying, let track = state.track else {
                showNothingPlaying = true
                return
            }
            // First go-live is where location makes sense: it is what puts
            // you on other people's Discover.
            locationService.requestAuthorizationIfNeeded()
            broadcast.attachLocationService(locationService)
            broadcast.updateCurrentTrack(track)
            await broadcast.startBroadcasting()
        }
    }

    private var goLiveTitle: String {
        if broadcast.isBroadcasting { return "You’re live" }
        return spotifyAuth.isAuthorized ? "Share what you’re playing" : "Connect Spotify to go live"
    }

    private var goLiveSubtitle: String {
        if broadcast.isBroadcasting {
            if let track = broadcast.currentTrack {
                return track.artist.isEmpty ? track.title : "\(track.title) · \(track.artist)"
            }
            return "People nearby can see your track"
        }
        return spotifyAuth.isAuthorized ? "Go live and show up here for people nearby" : "Takes a minute, then you’re on the map"
    }

    /// Two pills, not a system segmented control: "Nearby" and "People I follow".
    private var modePickerBar: some View {
        HStack(spacing: 8) {
            ForEach(DiscoverMode.allCases) { mode in
                let selected = viewModel.discoverMode == mode
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        viewModel.discoverMode = mode
                    }
                } label: {
                    Text(mode == .friends ? "People I follow" : mode.rawValue)
                        .font(.system(size: 13, weight: selected ? .heavy : .bold))
                        .foregroundColor(selected ? AppColors.background : AppColors.secondaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(selected ? AppColors.primaryText : AppColors.surface))
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 4)
        .padding(.bottom, 4)
    }

    private var locationDenied: Bool {
        locationService.authorizationStatus == .denied || locationService.authorizationStatus == .restricted
    }

    /// Radius slider when we know where the user is; an honest explanation
    /// when we don't. A slider that filters nothing is worse than none.
    @ViewBuilder
    private var locationBar: some View {
        if locationDenied {
            locationDeniedBanner
        } else if locationService.currentLocationPoint == nil {
            HStack(spacing: 8) {
                ProgressView().tint(.white).scaleEffect(0.8)
                Text("Finding your location…")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
                Spacer()
            }
            .padding(.horizontal, AppLayout.screenPadding)
            .padding(.vertical, 10)
        } else {
            radiusSlider
        }
    }

    private var locationDeniedBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "location.slash.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white.opacity(0.8))

            VStack(alignment: .leading, spacing: 2) {
                Text("Location is off")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text("Turn it on to see who is near you and how far away they are.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(AppColors.primary))
        }
        .padding(14)
        .melCard(cornerRadius: 14)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.vertical, 8)
    }

    private var radiusSlider: some View {
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "location.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white.opacity(0.65))

                Text("Within")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.65))

                Spacer()

                Text(formatRadius(viewModel.maxRadiusKm))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .monospacedDigit()
            }
            .padding(.horizontal, AppLayout.screenPadding)

            Slider(
                value: $viewModel.maxRadiusKm,
                in: DiscoverViewModel.minRadiusKm...DiscoverViewModel.maxRadiusKmAllowed,
                step: 1
            )
            .tint(AppColors.primary)
            .padding(.horizontal, AppLayout.screenPadding)
        }
        .padding(.top, 6)
        .padding(.bottom, 6)
    }

    private func formatRadius(_ km: Double) -> String {
        "\(Int(km.rounded())) km"
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.visibleBroadcasts.isEmpty && viewModel.recentBroadcasts.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Looking for people…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text("Couldn’t load Discover")
                    .font(AppFonts.headline())
                    .foregroundColor(.white)

                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    viewModel.retry()
                }
                .font(AppFonts.subheadline())
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.surfaceElevated)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        } else if viewModel.discoverMode == .friends && viewModel.followingIds.isEmpty {
            friendsEmptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 20) {
                    if viewModel.visibleBroadcasts.isEmpty {
                        nobodyLiveCard
                    } else {
                        sectionHeader("Live now", count: viewModel.visibleBroadcasts.count)
                        ForEach(viewModel.visibleBroadcasts) { broadcast in
                            card(for: broadcast)
                                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        }
                    }

                    if !viewModel.recentBroadcasts.isEmpty {
                        sectionHeader("Recently live", count: viewModel.recentBroadcasts.count)
                        ForEach(viewModel.recentBroadcasts) { broadcast in
                            card(for: broadcast)
                        }
                    }
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await viewModel.refresh()
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.85), value: viewModel.visibleBroadcasts.map(\.id))
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text("\(count)")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
                .monospacedDigit()
        }
        .padding(.horizontal, max(AppLayout.screenPadding, 20))
    }

    private func card(for broadcast: DiscoverBroadcast) -> some View {
        DiscoverCardView(
            broadcast: broadcast,
            isExpanded: Binding(
                get: { expandedCardId == broadcast.id },
                set: { newValue in
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        expandedCardId = newValue ? broadcast.id : nil
                    }
                }
            ),
            onDismiss: {
                viewModel.requestDismiss(for: broadcast)
            },
            onLikeTrack: {
                Task {
                    do {
                        try await viewModel.sendLike(for: broadcast, from: currentUserStore.user, message: nil)
                    } catch {
                        viewModel.presentActionError(error, fallback: "Couldn’t send your like. Please try again.")
                    }
                }
            },
            onMessage: { message in
                Task {
                    do {
                        try await viewModel.sendLike(for: broadcast, from: currentUserStore.user, message: message)
                    } catch {
                        viewModel.presentActionError(error, fallback: "Couldn’t send your message. Please try again.")
                    }
                }
            },
            onViewProfile: {
                viewModel.selectBroadcast(broadcast)
            },
            onToggleFollow: {
                Task { await viewModel.toggleFollow(broadcast) }
            },
            onOpenChat: {
                openChat(with: broadcast)
            },
            onOpenTrack: {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                trackSheetBroadcast = broadcast
            },
            hasLiked: viewModel.isLiked(broadcast),
            hasMessaged: viewModel.hasMessage(broadcast),
            isFollowing: viewModel.isFollowing(broadcast)
        )
        .padding(.horizontal, max(AppLayout.screenPadding, 20))
        .transition(.asymmetric(
            insertion: .move(edge: .top).combined(with: .opacity),
            removal: .opacity
        ))
    }

    // MARK: - Song sheet

    /// The song sheet reads live like/message state from the view model, so
    /// a like sent from the sheet shows on the card and vice versa. Profile
    /// and chat are presented from Discover after the sheet is down: two
    /// sheets on top of each other would fight.
    private func trackSheet(for broadcast: DiscoverBroadcast) -> some View {
        DiscoverTrackSheet(
            broadcast: broadcast,
            hasLiked: viewModel.isLiked(broadcast),
            hasMessaged: viewModel.hasMessage(broadcast),
            onLike: {
                // Thrown errors show inside the sheet.
                try await viewModel.sendLike(for: broadcast, from: currentUserStore.user, message: nil)
            },
            onMessage: { message in
                Task {
                    do {
                        try await viewModel.sendLike(for: broadcast, from: currentUserStore.user, message: message)
                    } catch {
                        viewModel.presentActionError(error, fallback: "Couldn’t send your message. Please try again.")
                    }
                }
            },
            onOpenChat: {
                pendingAfterTrackSheet = { openChat(with: broadcast) }
                trackSheetBroadcast = nil
            },
            onViewProfile: {
                pendingAfterTrackSheet = { viewModel.selectBroadcast(broadcast) }
                trackSheetBroadcast = nil
            },
            onHideTrack: {
                viewModel.muteTrack(for: broadcast)
            }
        )
        .environmentObject(spotifyAuth)
    }

    private func openChat(with broadcast: DiscoverBroadcast) {
        Task {
            if let id = await viewModel.conversationId(with: broadcast) {
                chatToOpen = ChatTarget(conversationId: id, peerId: broadcast.user.id)
            }
        }
    }

    // MARK: - Undo toast

    private func undoToast(_ undo: DiscoverViewModel.UndoAction) -> some View {
        HStack(spacing: 12) {
            Text(undo.message)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
            Spacer()
            Button("Undo") {
                viewModel.performUndo()
            }
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(AppColors.live)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Capsule().fill(AppColors.backgroundElevated)
                .shadow(color: .black.opacity(0.35), radius: 12, x: 0, y: 6)
        )
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.bottom, 12)
    }

    // MARK: - Empty states

    /// Shown at the top of the feed when nobody is live within the radius.
    /// Tells the truth about *why* and offers the one action that helps.
    private var nobodyLiveCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 36))
                .foregroundColor(.white.opacity(0.35))

            if viewModel.liveOutsideRadiusCount > 0 {
                Text("Nobody is live within \(formatRadius(viewModel.maxRadiusKm))")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(viewModel.liveOutsideRadiusCount == 1
                     ? "1 person is live a bit further away."
                     : "\(viewModel.liveOutsideRadiusCount) people are live a bit further away.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Button {
                    viewModel.widenRadiusToNearestLive()
                } label: {
                    Label("Widen radius", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                }
            } else {
                Text(viewModel.discoverMode == .friends ? "No one you follow is live right now" : "No one is live right now")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                Text(viewModel.discoverMode == .friends
                     ? "You’ll see them here the moment they go live, wherever they are."
                     : "Go live yourself: the moment someone nearby starts playing, they show up here and you get notified.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Button {
                    goLive()
                } label: {
                    Label("Go live", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppColors.live)
                        .clipShape(Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 20)
        .melCard(cornerRadius: 18)
        .padding(.horizontal, max(AppLayout.screenPadding, 20))
    }

    private var friendsEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.3))

            Text("You're not following anyone yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)

            Text("Follow people to see when they go live here.")
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button {
                showUserSearch = true
            } label: {
                Label("Find People", systemImage: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(AppColors.primary)
                    .clipShape(Capsule())
            }

            Spacer()
        }
    }

    private var isRunningInPreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }
}

#Preview {
    DiscoverView()
        .environmentObject(CurrentUserStore())
        .environmentObject(LocationService())
        .environmentObject(AppRouter.shared)
        .environmentObject(BroadcastManager())
        .environmentObject(SpotifyAuthManager.shared)
}
