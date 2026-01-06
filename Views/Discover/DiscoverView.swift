import SwiftUI

struct DiscoverView: View {

    @StateObject private var vm = DiscoverViewModel()

    @EnvironmentObject private var currentUserStore: CurrentUserStore

    // Like sheet state
    @State private var likeTargetUser: AppUser?
    @State private var likeTrack: Track?
    @State private var likeMessage: String = ""
    @State private var isSendingLike: Bool = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                content
            }
            .navigationTitle("Discover")
            .navigationBarTitleDisplayMode(.large)
            .onAppear { vm.startListening() }
            .onDisappear { vm.stopListening() }
            .sheet(
                isPresented: Binding(
                    get: { likeTargetUser != nil && likeTrack != nil },
                    set: { newValue in
                        if !newValue {
                            resetLikeSheet()
                        }
                    }
                )
            ) {
                LikeMessageSheet(
                    targetUser: likeTargetUser,
                    track: likeTrack,
                    message: $likeMessage,
                    isSending: isSendingLike,
                    onSend: {
                        Task { await sendLike() }
                    },
                    onCancel: {
                        resetLikeSheet()
                    }
                )
                .presentationDetents([.medium])
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if vm.isLoading && vm.broadcasters.isEmpty {
            VStack {
                Spacer()
                ProgressView("Loading broadcasters…").tint(.white)
                Spacer()
            }
        } else if let error = vm.errorMessage {
            VStack(spacing: 10) {
                Text("Couldn’t load broadcasters")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                Text(error)
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)

                Button("Retry") { vm.startListening() }
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.18))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .padding(.horizontal, AppLayout.screenPadding)
        } else if vm.broadcasters.isEmpty {
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
                VStack(spacing: 12) {
                    ForEach(vm.broadcasters, id: \.id) { user in
                        DiscoverUserRow(
                            user: user,
                            onLikeTap: { u, t in
                                likeTargetUser = u
                                likeTrack = t
                                likeMessage = ""
                            }
                        )
                    }
                }
                .padding(.horizontal, AppLayout.screenPadding)
                .padding(.vertical, 12)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func sendLike() async {
        guard let toUser = likeTargetUser, let track = likeTrack else { return }

        isSendingLike = true
        defer { isSendingLike = false }

        do {
            _ = try await LikeApiService.shared.likeBroadcastTrack(
                fromUser: currentUserStore.user,     // ✅ so werden Name/Avatar im Like gespeichert
                toUser: toUser,
                track: track,
                sessionLocation: toUser.lastLocation,
                placeLabel: nil,
                message: likeMessage
            )

            resetLikeSheet()
        } catch {
            print("❌ Like send failed:", error.localizedDescription)
        }
    }

    private func resetLikeSheet() {
        likeTargetUser = nil
        likeTrack = nil
        likeMessage = ""
        isSendingLike = false
    }
}

// MARK: - Row (separater Wrapper: Card + Like Button)

struct DiscoverUserRow: View {

    let user: AppUser
    let onLikeTap: (AppUser, Track) -> Void

    var body: some View {
        HStack(spacing: 10) {

            NavigationLink {
                UserProfileDetailView(userId: user.id)
            } label: {
                DiscoverUserCard(user: user)
            }
            .buttonStyle(.plain)

            Button {
                guard let track = user.currentTrack else { return }
                onLikeTap(user, track)
            } label: {
                Image(systemName: "heart")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(AppColors.primaryText)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(AppColors.cardBackground.opacity(0.98))
                    )
                    .shadow(color: Color.black.opacity(0.10), radius: 8, x: 0, y: 6)
            }
            .buttonStyle(.plain)
            .disabled(user.currentTrack == nil)
        }
    }
}

