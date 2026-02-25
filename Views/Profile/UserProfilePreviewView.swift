import SwiftUI
import CoreLocation

/// Unified profile view for viewing other users' profiles.
/// Accepts either a userId (loads from Firestore) or an AppUser directly.
/// Uses SharedProfilePreviewView for consistent UI with your own profile.
struct UserProfilePreviewView: View {

    private let initialUser: AppUser?
    private let userId: String

    @StateObject private var vm = UserProfilePreviewViewModel()
    @EnvironmentObject private var locationService: LocationService
    @State private var isFollowing = false
    @State private var isLoadingFollow = true

    // MARK: - Init

    /// Init with userId – loads user from Firestore
    init(userId: String) {
        self.userId = userId
        self.initialUser = nil
    }

    /// Init with AppUser – skips Firestore fetch
    init(user: AppUser) {
        self.userId = user.uid
        self.initialUser = user
    }

    // MARK: - Body

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
                            followSection(for: user)

                            let previewData = ProfilePreviewData.from(
                                appUser: user,
                                distanceMeters: distanceToUser(user)
                            )
                            SharedProfilePreviewView(data: previewData, userId: user.uid)
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
        .task {
            if let initialUser {
                vm.user = initialUser
            } else {
                await vm.loadUser(userId: userId)
            }
            // Load follow state
            isFollowing = (try? await FollowApiService.shared.isFollowing(userId: userId)) ?? false
            isLoadingFollow = false
        }
    }

    // MARK: - Distance Calculation

    private func distanceToUser(_ user: AppUser) -> Double? {
        guard let myLoc = locationService.currentLocationPoint,
              let otherLoc = user.lastLocation else { return nil }
        let a = CLLocation(latitude: myLoc.latitude, longitude: myLoc.longitude)
        let b = CLLocation(latitude: otherLoc.latitude, longitude: otherLoc.longitude)
        return a.distance(from: b)
    }

    // MARK: - Follow Section

    private func followSection(for user: AppUser) -> some View {
        HStack {
            Spacer()

            if !isLoadingFollow {
                Button {
                    Task {
                        if isFollowing {
                            try? await FollowApiService.shared.unfollow(userId: user.uid)
                            isFollowing = false
                        } else {
                            try? await FollowApiService.shared.follow(userId: user.uid)
                            isFollowing = true
                        }
                    }
                } label: {
                    Text(isFollowing ? "Following" : "Follow")
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundColor(isFollowing ? AppColors.primaryText : .white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 9)
                        .background(isFollowing ? Color.gray.opacity(0.2) : AppColors.primary)
                        .clipShape(Capsule())
                }
            }
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
