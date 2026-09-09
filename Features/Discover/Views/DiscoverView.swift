import SwiftUI
import CoreLocation

struct DiscoverView: View {

    @StateObject private var viewModel = DiscoverViewModel()

    @EnvironmentObject private var currentUserStore: CurrentUserStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var router: AppRouter

    @State private var showUserSearch = false
    @State private var expandedCardId: String?
    @State private var chatToOpen: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    modePickerBar
                    locationBar
                    content
                }
            }
            .melScreenBackground()
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showUserSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Find people")
                }
            }
            .navigationDestination(item: $chatToOpen) { conversationId in
                ChatView(conversationId: conversationId)
            }
            .sheet(isPresented: $showUserSearch) {
                UserSearchView()
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

    private var modePickerBar: some View {
        Picker("Mode", selection: $viewModel.discoverMode) {
            ForEach(DiscoverMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppLayout.screenPadding)
        .padding(.top, 8)
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
                    .font(.system(size: 12, weight: .medium, design: .rounded))
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
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("Turn it on to see who is near you and how far away they are.")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))
            }

            Spacer()

            Button("Open Settings") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.65))

                Spacer()

                Text(formatRadius(viewModel.maxRadiusKm))
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                    .font(.system(size: 14, weight: .medium, design: .rounded))
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
                VStack(spacing: 20) {
                    if viewModel.visibleBroadcasts.isEmpty {
                        nobodyLiveCard
                    } else {
                        sectionHeader("Live now", count: viewModel.visibleBroadcasts.count)
                        ForEach(viewModel.visibleBroadcasts) { broadcast in
                            card(for: broadcast)
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
            .animation(.easeInOut(duration: 0.3), value: viewModel.visibleBroadcasts.map(\.id))
        }
    }

    private func sectionHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.6))
            Spacer()
            Text("\(count)")
                .font(.system(size: 13, weight: .semibold, design: .rounded))
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
                Task {
                    if let id = await viewModel.conversationId(with: broadcast) {
                        chatToOpen = id
                    }
                }
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
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
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
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppColors.primary)
                        .clipShape(Capsule())
                }
            } else {
                Text(viewModel.discoverMode == .friends ? "None of your friends are live" : "No one is live right now")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                Text("Go live yourself: the moment someone nearby starts playing, they show up here and you get notified.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)

                Button {
                    router.goLive()
                } label: {
                    Label("Go live", systemImage: "dot.radiowaves.left.and.right")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
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
                .font(.system(size: 18, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            Text("Follow people to see their broadcasts here.")
                .font(AppFonts.footnote())
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button {
                showUserSearch = true
            } label: {
                Label("Find People", systemImage: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
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
}
