import Foundation
import FirebaseAuth

@MainActor
final class ProfileTabViewModel: ObservableObject {
    
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var user: AppUser?
    
    private let userService: UserApiService
    
    init(userService: UserApiService = .shared) {
        self.userService = userService
    }
    
    func loadCurrentUser() {
        errorMessage = nil
        isLoading = true
        
        guard let uid = Auth.auth().currentUser?.uid else {
            isLoading = false
            errorMessage = "No Firebase user signed in."
            return
        }
        
        userService.getUser(uid: uid) { [weak self] result in
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
