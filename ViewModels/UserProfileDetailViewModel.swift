import Foundation

@MainActor
final class UserProfileDetailViewModel: ObservableObject {
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var user: AppUser?
    
    private let userService: UserApiService
    
    init(userService: UserApiService = .shared) {
        self.userService = userService
    }
    
    func load(userId: String) {
        errorMessage = nil
        isLoading = true
        
        userService.getUser(uid: userId) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            
            switch result {
            case .failure(let err):
                self.errorMessage = err.localizedDescription
            case .success(let u):
                self.user = u
            }
        }
    }
}
