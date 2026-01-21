import SwiftUI

struct DiscoverView: View {

    @StateObject private var viewModel = DiscoverViewModel()

    @EnvironmentObject private var currentUserStore: CurrentUserStore
    @EnvironmentObject private var locationService: LocationService

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

                content
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .sheet(item: $viewModel.selectedBroadcast) { broadcast in
                DiscoverDetailSheetView(
                    broadcast: broadcast,
                    isSending: viewModel.isSendingLike,
                    onLike: {
                        Task {
                            try? await viewModel.sendLike(
                                for: broadcast,
                                from: currentUserStore.user,
                                message: nil
                            )
                        }
                    },
                    onSendMessage: { message in
                        Task {
                            try? await viewModel.sendLike(
                                for: broadcast,
                                from: currentUserStore.user,
                                message: message
                            )
                        }
                    }
                )
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
            VStack(spacing: 10) {
                Text("No one is live right now")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text("When someone nearby starts broadcasting, they’ll show up here.")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }
            .padding(.top, 40)
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(viewModel.visibleBroadcasts) { broadcast in
                        DiscoverCardView(
                            broadcast: broadcast,
                            onTap: {
                                viewModel.selectBroadcast(broadcast)
                            },
                            onDismiss: {
                                viewModel.requestDismiss(for: broadcast)
                            }
                        )
                        // Keep the card big, but NEVER touch screen edges:
                        .frame(maxWidth: 420)
                        .padding(.horizontal, max(AppLayout.screenPadding, 28))
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.requestDismiss(for: broadcast)
                            } label: {
                                Label("Dismiss", systemImage: "xmark")
                            }
                        }
                    }
                }
                .padding(.vertical, 18)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
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

