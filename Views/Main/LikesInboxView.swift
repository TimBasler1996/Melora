import SwiftUI

struct LikesInboxView: View {

    enum InboxTab: String, CaseIterable {
        case likes = "Likes"
        case followers = "Followers"
    }

    let user: AppUser
    /// Presented modally (Now tab) → X button; pushed (Chats, Profile) → none.
    var showsCloseButton: Bool = true
    @StateObject private var vm = LikesInboxViewModel()
    @StateObject private var followersVM = FollowersInboxViewModel()
    @State private var selectedTab: InboxTab = .likes
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Segmented control
                Picker("", selection: $selectedTab) {
                    ForEach(InboxTab.allCases, id: \.self) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                switch selectedTab {
                case .likes:
                    likesContent
                case .followers:
                    followersContent
                }
            }
        }
        .melScreenBackground()
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(selectedTab.rawValue)
                    .font(AppFonts.headline())
                    .foregroundColor(.white)
            }

            ToolbarItem(placement: .topBarLeading) {
                if showsCloseButton {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(AppColors.surfaceElevated)
                        )
                }
                }
            }
        }
        .onAppear {
            vm.loadLikes(for: user.uid)
            followersVM.startListening()
        }
        .onDisappear {
            vm.markAllAsSeen()
            followersVM.markAllAsSeen()
            followersVM.stopListening()
        }
        .refreshable {
            if selectedTab == .likes {
                vm.loadLikes(for: user.uid)
            } else {
                followersVM.startListening()
            }
        }
    }

    // MARK: - Likes Content

    @ViewBuilder
    private var likesContent: some View {
        if vm.isLoading && vm.clusters.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Loading likes…")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 12)
                Spacer()
            }
        } else if let err = vm.errorMessage {
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(.white.opacity(0.4))

                Text("Couldn't load likes")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                Text(err)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Button {
                    vm.loadLikes(for: user.uid)
                } label: {
                    Text("Retry")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.white))
                }
                .padding(.top, 8)

                Spacer()
            }
            .padding(.horizontal, 20)
        } else if vm.clusters.isEmpty {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "heart")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.white.opacity(0.4))

                VStack(spacing: 8) {
                    Text("No Likes Yet")
                        .font(AppFonts.title())
                        .foregroundColor(.white)

                    Text("When someone likes a track you\nplayed live, it will show up here")
                        .font(AppFonts.body())
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !vm.todayClusters.isEmpty {
                        sectionHeader("Today")
                        ForEach(vm.todayClusters) { cluster in
                            NavigationLink {
                                TrackLikesDetailView(user: user, track: cluster.asTrack, likes: cluster.likes)
                            } label: {
                                ModernTrackLikesClusterRow(cluster: cluster)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if !vm.earlierClusters.isEmpty {
                        sectionHeader("Earlier")
                        ForEach(vm.earlierClusters) { cluster in
                            NavigationLink {
                                TrackLikesDetailView(user: user, track: cluster.asTrack, likes: cluster.likes)
                            } label: {
                                ModernTrackLikesClusterRow(cluster: cluster)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.5))
            Spacer()
        }
        .padding(.top, title == "Earlier" ? 8 : 0)
    }

    // MARK: - Followers Content

    @ViewBuilder
    private var followersContent: some View {
        if followersVM.isLoading && followersVM.followers.isEmpty {
            VStack {
                Spacer()
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.2)
                Text("Loading followers…")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.top, 12)
                Spacer()
            }
        } else if let err = followersVM.errorMessage, followersVM.followers.isEmpty {
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "exclamationmark.triangle")
                    .font(.system(size: 48, weight: .thin))
                    .foregroundColor(.white.opacity(0.4))
                Text("Couldn't load followers")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(err)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Button {
                    followersVM.startListening()
                } label: {
                    Text("Retry")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 14)
                        .background(Capsule().fill(Color.white))
                }
                .padding(.top, 8)
                Spacer()
            }
            .padding(.horizontal, 20)
        } else if followersVM.followers.isEmpty {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "person.2")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.white.opacity(0.4))

                VStack(spacing: 8) {
                    Text("No Followers Yet")
                        .font(AppFonts.title())
                        .foregroundColor(.white)

                    Text("When someone follows you,\nthey'll appear here")
                        .font(AppFonts.body())
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    if !followersVM.newFollowers.isEmpty {
                        sectionHeader("New")
                        ForEach(followersVM.newFollowers) { follower in
                            FollowerRowView(follower: follower)
                        }
                    }
                    if !followersVM.earlierFollowers.isEmpty {
                        sectionHeader("Earlier")
                        ForEach(followersVM.earlierFollowers) { follower in
                            FollowerRowView(follower: follower)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
    }
}

// MARK: - Follower Row

private struct FollowerRowView: View {
    let follower: FollowerEntry
    @State private var isFollowingBack: Bool = false
    @State private var checkedFollow: Bool = false
    @State private var isUpdatingFollow: Bool = false
    @State private var followError: String?

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Group {
                if let urlString = follower.avatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle().fill(AppColors.surface)
                                .overlay(ProgressView().tint(.white))
                        case .success(let image):
                            image.resizable().scaledToFill()
                        default:
                            followerPlaceholder
                        }
                    }
                } else {
                    followerPlaceholder
                }
            }
            .frame(width: 48, height: 48)
            .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(follower.displayName ?? "Loading…")
                    .font(AppFonts.headline())
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("started following you")
                    .font(AppFonts.footnote())
                    .foregroundColor(.white.opacity(0.5))

                Text(follower.followedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }

            Spacer()

            if checkedFollow {
                Button {
                    Task { await toggleFollowBack() }
                } label: {
                    Text(isFollowingBack ? "Following" : "Follow back")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(isFollowingBack ? .white.opacity(0.7) : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(isFollowingBack ? AppColors.surfaceElevated : AppColors.primary)
                        )
                }
                .disabled(isUpdatingFollow)
                .opacity(isUpdatingFollow ? 0.6 : 1)
            }
        }
        .padding(14)
        .melCard(cornerRadius: 12)
        .task {
            isFollowingBack = (try? await FollowApiService.shared.isFollowing(userId: follower.userId)) ?? false
            checkedFollow = true
        }
        .alert(
            "Couldn’t do that",
            isPresented: Binding(get: { followError != nil }, set: { if !$0 { followError = nil } })
        ) {
            Button("OK", role: .cancel) { followError = nil }
        } message: {
            Text(followError ?? "")
        }
    }

    /// Optimistic toggle; rolls back and explains if the write fails.
    private func toggleFollowBack() async {
        let wasFollowing = isFollowingBack
        isFollowingBack.toggle()
        isUpdatingFollow = true
        defer { isUpdatingFollow = false }
        do {
            if wasFollowing {
                try await FollowApiService.shared.unfollow(userId: follower.userId)
            } else {
                try await FollowApiService.shared.follow(userId: follower.userId)
            }
        } catch {
            isFollowingBack = wasFollowing
            followError = UserFacingError.message(
                for: error,
                fallback: wasFollowing ? "Couldn’t unfollow. Please try again." : "Couldn’t follow back. Please try again."
            )
        }
    }

    private var followerPlaceholder: some View {
        ZStack {
            Circle().fill(AppColors.surface)
            Image(systemName: "person.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
    }
}

// MARK: - Modern Track Likes Cluster Row

private struct ModernTrackLikesClusterRow: View {
    let cluster: TrackLikesCluster
    
    var body: some View {
        HStack(spacing: 14) {
            // Album artwork
            Group {
                if let urlString = cluster.trackArtworkURL,
                   let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Rectangle()
                                .fill(AppColors.surface)
                                .overlay(
                                    ProgressView()
                                        .tint(.white)
                                )
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure:
                            placeholderArtwork
                        @unknown default:
                            placeholderArtwork
                        }
                    }
                } else {
                    placeholderArtwork
                }
            }
            .frame(width: 64, height: 64)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            
            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(cluster.trackTitle)
                    .font(AppFonts.headline())
                    .foregroundColor(AppColors.primaryText)
                    .lineLimit(1)

                Text(cluster.trackArtist)
                    .font(AppFonts.subheadline())
                    .foregroundColor(AppColors.secondaryText)
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(cluster.likes.count) like\(cluster.likes.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(AppColors.live)
                .padding(.top, 2)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .melCard(cornerRadius: 12)
    }

    private var placeholderArtwork: some View {
        Rectangle()
            .fill(AppColors.surface)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .thin))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}
