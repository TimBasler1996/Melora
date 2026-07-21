import SwiftUI

struct DiscoverView: View {

    @StateObject private var viewModel = DiscoverViewModel()

    @EnvironmentObject private var currentUserStore: CurrentUserStore
    @EnvironmentObject private var locationService: LocationService

    @State private var showUserSearch = false
    @State private var expandedCardId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    modePickerBar
                    radiusSlider
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
                    }
                }
            }
            .sheet(isPresented: $showUserSearch) {
                UserSearchView()
            }
            .sheet(item: $viewModel.selectedBroadcast) { broadcast in
                NavigationStack {
                    UserProfilePreviewView(userId: broadcast.user.id)
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
                    Button("Not interested in this song") {
                        viewModel.muteTrack(for: target)
                    }
                    Button("Not interested in this user", role: .destructive) {
                        viewModel.muteUser(for: target)
                    }
                }
                Button("Cancel", role: .cancel) {
                    viewModel.cancelDismiss()
                }
            }
            .alert(
                "Something went wrong",
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
        let rounded = Int(km.rounded())
        return "\(rounded) km"
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading && viewModel.visibleBroadcasts.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Loading broadcasts…")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                Spacer()
            }
        } else if let error = viewModel.errorMessage {
            VStack(spacing: 12) {
                Text("Couldn’t load broadcasts")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)

                Button("Retry") {
                    viewModel.startListening()
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(AppColors.surfaceElevated)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        } else if viewModel.visibleBroadcasts.isEmpty {
            if viewModel.discoverMode == .friends {
                friendsEmptyState
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 44))
                        .foregroundColor(.white.opacity(0.3))

                    Text("No one is live right now")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("When someone nearby starts broadcasting, they'll show up here.")
                        .font(AppFonts.footnote())
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, 60)
            }
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.visibleBroadcasts) { broadcast in
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
                                        try await viewModel.sendLike(
                                            for: broadcast,
                                            from: currentUserStore.user,
                                            message: nil
                                        )
                                    } catch {
                                        viewModel.actionError = "Couldn’t send your like. Please try again."
                                    }
                                }
                            },
                            onMessage: { message in
                                Task {
                                    do {
                                        try await viewModel.sendLike(
                                            for: broadcast,
                                            from: currentUserStore.user,
                                            message: message
                                        )
                                    } catch {
                                        viewModel.actionError = "Couldn’t send your message. Please try again."
                                    }
                                }
                            },
                            onViewProfile: {
                                viewModel.selectBroadcast(broadcast)
                            },
                            onToggleFollow: {
                                Task { await viewModel.toggleFollow(broadcast) }
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

    private var friendsEmptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 44))
                .foregroundColor(.white.opacity(0.3))

            if viewModel.followingIds.isEmpty {
                Text("You're not following anyone yet")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("Follow people to see their broadcasts here.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            } else {
                Text("None of your friends are live")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("When someone you follow starts broadcasting, they'll show up here.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

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
}

