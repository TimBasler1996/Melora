import SwiftUI

/// Profile view for viewing other users' profiles
/// ✅ Uses shared component for consistent UI with your own profile
struct UserProfilePreviewView: View {
    
    let userId: String
    
    @StateObject private var vm = UserProfilePreviewViewModel()
    @Environment(\.dismiss) private var dismiss
    
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
        .task {
            await vm.loadUser(userId: userId)
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
            // Fetch user from Firestore
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
