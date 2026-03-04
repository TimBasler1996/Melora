import SwiftUI

/// Profile view for viewing other users' profiles
struct UserProfilePreviewView: View {

    let userId: String

    @StateObject private var vm = UserProfilePreviewViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var isFollowing: Bool = false
    @State private var isLoadingFollow: Bool = true
    @State private var showBlockConfirm = false

    var body: some View {
        GeometryReader { geo in
            let contentWidth = geo.size.width - (AppLayout.screenPadding * 2)

            ZStack {
                AppColors.background.ignoresSafeArea()

                if vm.isLoading {
                    loadingState
                } else if let error = vm.errorMessage {
                    errorState(error)
                } else if let user = vm.user {
                    ScrollView(.vertical) {
                        VStack(spacing: 16) {
                            let previewData = ProfilePreviewData.from(appUser: user)
                            SharedProfilePreviewView(data: previewData)
                        }
                        .frame(width: contentWidth, alignment: .center)
                        .padding(.bottom, 28)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 12) {
                    if !isLoadingFollow {
                        Button {
                            Task {
                                if isFollowing {
                                    try? await FollowApiService.shared.unfollow(userId: userId)
                                    isFollowing = false
                                } else {
                                    try? await FollowApiService.shared.follow(userId: userId)
                                    isFollowing = true
                                }
                            }
                        } label: {
                            Text(isFollowing ? "Following" : "Follow")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(isFollowing ? .white.opacity(0.7) : .white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(isFollowing ? Color.white.opacity(0.12) : AppColors.primary)
                                .clipShape(Capsule())
                        }
                    }

                    Menu {
                        Button(role: .destructive) {
                            showBlockConfirm = true
                        } label: {
                            Label("Block User", systemImage: "hand.raised")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .confirmationDialog("Block this user?", isPresented: $showBlockConfirm, titleVisibility: .visible) {
            Button("Block User", role: .destructive) {
                Task {
                    try? await BlockService.shared.blockUser(userId: userId)
                    dismiss()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They won't appear in your Discover, Chats, or Likes.")
        }
        .task {
            await vm.loadUser(userId: userId)
            isFollowing = (try? await FollowApiService.shared.isFollowing(userId: userId)) ?? false
            isLoadingFollow = false
        }
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

    func loadUser(userId: String) async {
        isLoading = true
        errorMessage = nil
        user = nil

        do {
            let fetchedUser = try await fetchUser(uid: userId)
            user = fetchedUser
            isLoading = false
            print("✅ [ProfilePreview] Loaded profile for \(fetchedUser.displayName)")
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            print("❌ [ProfilePreview] Failed to load user: \(error)")
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
