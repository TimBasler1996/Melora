import SwiftUI
import FirebaseAuth

/// Unified profile view used everywhere a user's profile is opened from.
/// Shows the same layout for any user; renders a Follow / Following button
/// when viewing someone else's profile (Instagram-style).
struct UserProfilePreviewView: View {

    let userId: String

    @StateObject private var vm = UserProfilePreviewViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            AppColors.background.ignoresSafeArea()

            if vm.isLoading {
                loadingState
            } else if let error = vm.errorMessage {
                errorState(error)
            } else if let user = vm.user {
                ScrollView(.vertical) {
                    VStack(spacing: 16) {
                        if !vm.isOwnProfile {
                            followBar
                        }

                        let previewData = ProfilePreviewData.from(
                            appUser: user,
                            followerCount: vm.followerCount,
                            likesReceivedCount: vm.likesReceivedCount
                        )
                        SharedProfilePreviewView(data: previewData)
                    }
                    .padding(.horizontal, AppLayout.screenPadding)
                    .padding(.bottom, 28)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await vm.load(userId: userId)
        }
    }

    // MARK: - Follow Bar

    private var followBar: some View {
        Button {
            Task { await vm.toggleFollow() }
        } label: {
            HStack(spacing: 6) {
                if vm.isFollowLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: vm.isFollowing ? AppColors.primaryText : .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: vm.isFollowing ? "checkmark" : "plus")
                        .font(.system(size: 13, weight: .bold))
                }
                Text(vm.isFollowing ? "Following" : "Follow")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
            }
            .foregroundColor(vm.isFollowing ? AppColors.primaryText : .white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: AppLayout.cornerRadiusMedium, style: .continuous)
                    .fill(vm.isFollowing ? Color.white.opacity(0.15) : AppColors.primary)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(vm.isFollowLoading)
    }

    // MARK: - Loading State

    private var loadingState: some View {
        VStack(spacing: 16) {
            ProgressView().tint(AppColors.primary)
            Text("Loading profile…")
                .font(AppFonts.footnote())
                .foregroundColor(AppColors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    // MARK: - Error State

    private func errorState(_ error: String) -> some View {
        Text(error)
            .font(AppFonts.body())
            .foregroundColor(AppColors.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
    }
}

// MARK: - ViewModel

@MainActor
final class UserProfilePreviewViewModel: ObservableObject {

    @Published var user: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var followerCount: Int?
    @Published var likesReceivedCount: Int?
    @Published var isFollowing: Bool = false
    @Published var isFollowLoading: Bool = false

    private var loadedUserId: String?

    var isOwnProfile: Bool {
        guard let loadedUserId else { return false }
        return Auth.auth().currentUser?.uid == loadedUserId
    }

    func load(userId: String) async {
        loadedUserId = userId
        isLoading = true
        errorMessage = nil
        user = nil

        do {
            let fetchedUser = try await fetchUser(uid: userId)
            user = fetchedUser
            isLoading = false
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return
        }

        async let followerCountFetch = FollowApiService.shared.fetchFollowerCount(of: userId)
        async let likesFetch = LikeApiService.shared.fetchLikesReceivedCount(for: userId)
        async let followingCheck = FollowApiService.shared.isFollowing(userId: userId)

        followerCount = (try? await followerCountFetch) ?? 0
        likesReceivedCount = (try? await likesFetch) ?? 0
        isFollowing = (try? await followingCheck) ?? false
    }

    func toggleFollow() async {
        guard let loadedUserId, !isOwnProfile else { return }

        isFollowLoading = true
        defer { isFollowLoading = false }

        let wasFollowing = isFollowing
        // Optimistic update
        isFollowing.toggle()
        followerCount = max(0, (followerCount ?? 0) + (wasFollowing ? -1 : 1))

        do {
            if wasFollowing {
                try await FollowApiService.shared.unfollow(userId: loadedUserId)
            } else {
                try await FollowApiService.shared.follow(userId: loadedUserId)
            }
        } catch {
            // Roll back optimistic update
            isFollowing = wasFollowing
            followerCount = max(0, (followerCount ?? 0) + (wasFollowing ? 1 : -1))
            print("Follow toggle failed: \(error)")
        }
    }

    private func fetchUser(uid: String) async throws -> AppUser {
        return try await withCheckedThrowingContinuation { continuation in
            UserApiService.shared.fetchUser(uid: uid) { result in
                continuation.resume(with: result)
            }
        }
    }
}
