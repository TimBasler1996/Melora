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
                // Dark gradient background matching other views
                LinearGradient(
                    colors: [
                        Color(red: 0.15, green: 0.15, blue: 0.2),
                        Color.black.opacity(0.95)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                VStack(spacing: 0) {
                    modePickerBar
                    content
                }
            }
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
            .task {
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
                .background(Color.white.opacity(0.18))
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        } else if viewModel.visibleBroadcasts.isEmpty {
            if viewModel.discoverMode == .friends {
                friendsEmptyState
            } else {
                VStack(spacing: 10) {
                    Text("No one is live right now")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)

                    Text("When someone nearby starts broadcasting, they'll show up here.")
                        .font(AppFonts.footnote())
                        .foregroundColor(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .padding(.top, 40)
            }
        } else {
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(viewModel.visibleBroadcasts) { broadcast in
                        DiscoverCardView(
                            broadcast: broadcast,
                            onDismiss: {
                                viewModel.requestDismiss(for: broadcast)
                            },
                            onLikeTrack: {
                                Task {
                                    try? await viewModel.sendLike(
                                        for: broadcast,
                                        from: currentUserStore.user,
                                        message: nil
                                    )
                                }
                            },
                            onMessage: { message in
                                Task {
                                    try? await viewModel.sendLike(
                                        for: broadcast,
                                        from: currentUserStore.user,
                                        message: message
                                    )
                                }
                            },
                            hasLiked: viewModel.isLiked(broadcast),
                            hasMessaged: viewModel.hasMessage(broadcast),
                            expandedId: $expandedCardId
                        )
                        .padding(.horizontal, AppLayout.screenPadding)
                    }
                }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
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
                Text("No one you follow is live")
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

