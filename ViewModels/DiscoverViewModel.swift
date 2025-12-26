import Foundation
import FirebaseFirestore

@MainActor
final class DiscoverViewModel: ObservableObject {

    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var broadcasters: [AppUser] = []

    private let userService: UserApiService
    private var listener: ListenerRegistration?

    init(userService: UserApiService = .shared) {
        self.userService = userService
    }

    func startListening() {
        errorMessage = nil
        isLoading = true

        listener?.remove()
        listener = userService.listenToBroadcastingUsers(limit: 50) { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.broadcasters = []
            case .success(let users):
                self.errorMessage = nil
                self.broadcasters = users
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
    }
}

