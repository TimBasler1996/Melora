import SwiftUI

struct LikesInboxView: View {

    enum InboxTab: String, CaseIterable {
        case likes = "Likes"
        case followers = "Followers"
    }

    let user: AppUser
    @StateObject private var vm = LikesInboxViewModel()
    @StateObject private var followersVM = FollowersInboxViewModel()
    @State private var selectedTab: InboxTab = .likes
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(selectedTab.rawValue)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }

            ToolbarItem(placement: .topBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.white.opacity(0.12))
                        )
                }
            }
        }
        .onAppear {
            vm.loadLikes(for: user.uid)
            followersVM.startListening()
        }
        .onDisappear {
            vm.markAllAsSeen()
            followersVM.stopListening()
        }
        .refreshable {
            if selectedTab == .likes {
                vm.loadLikes(for: user.uid)
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
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("When someone likes a track you\nbroadcast, it will show up here")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(vm.clusters) { cluster in
                        NavigationLink {
                            TrackLikesDetailView(user: user, track: cluster.asTrack, likes: cluster.likes)
                        } label: {
                            ModernTrackLikesClusterRow(cluster: cluster)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
        }
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
        } else if followersVM.followers.isEmpty {
            VStack(spacing: 20) {
                Spacer()

                Image(systemName: "person.2")
                    .font(.system(size: 64, weight: .thin))
                    .foregroundColor(.white.opacity(0.4))

                VStack(spacing: 8) {
                    Text("No Followers Yet")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundColor(.white)

                    Text("When someone follows you,\nthey'll appear here")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }

                Spacer()
            }
            .padding(.horizontal, 32)
        } else {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(followersVM.followers) { follower in
                        FollowerRowView(follower: follower)
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

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            Group {
                if let urlString = follower.avatarURL, let url = URL(string: urlString) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .empty:
                            Circle().fill(Color.white.opacity(0.08))
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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text("started following you")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.5))

                Text(follower.followedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
            }

            Spacer()

            if checkedFollow {
                Button {
                    Task {
                        if isFollowingBack {
                            try? await FollowApiService.shared.unfollow(userId: follower.userId)
                            isFollowingBack = false
                        } else {
                            try? await FollowApiService.shared.follow(userId: follower.userId)
                            isFollowingBack = true
                        }
                    }
                } label: {
                    Text(isFollowingBack ? "Following" : "Follow back")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(isFollowingBack ? .white.opacity(0.7) : .white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(
                            Capsule().fill(isFollowingBack ? Color.white.opacity(0.12) : AppColors.primary)
                        )
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
        .task {
            isFollowingBack = (try? await FollowApiService.shared.isFollowing(userId: follower.userId)) ?? false
            checkedFollow = true
        }
    }

    private var followerPlaceholder: some View {
        ZStack {
            Circle().fill(Color.white.opacity(0.08))
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
                                .fill(Color.white.opacity(0.08))
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
                    .font(.system(size: 16, weight: .semibold, design: .default))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(cluster.trackArtist)
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .foregroundColor(.white.opacity(0.6))
                    .lineLimit(1)
                
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("\(cluster.likes.count) like\(cluster.likes.count == 1 ? "" : "s")")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                .foregroundColor(Color(red: 0.2, green: 0.85, blue: 0.4))
                .padding(.top, 2)
            }
            
            Spacer()
            
            // Chevron
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.3))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.white.opacity(0.08))
        )
    }
    
    private var placeholderArtwork: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 24, weight: .thin))
                    .foregroundColor(.white.opacity(0.3))
            )
    }
}
