//
//  DiscoverViewModel.swift
//  SocialSound
//

import Foundation
import FirebaseAuth

@MainActor
final class DiscoverViewModel: ObservableObject {

    @Published var broadcasters: [AppUser] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let userService: UserApiService
    private var isListening = false

    init(userService: UserApiService = .shared) {
        self.userService = userService
    }

    deinit {
        // deinit is nonisolated, so hop to main actor safely
        Task { @MainActor in
            self.stopListening()
        }
    }

    func refresh() {
        startListening()
    }

    func startListening() {
        if isListening { return }
        isListening = true

        errorMessage = nil
        isLoading = true

        let myUID = Auth.auth().currentUser?.uid ?? "nil"
        print("🟣 [Discover] startListening() myUID=\(myUID)")

        userService.observeBroadcastingUsers { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .failure(let error):
                self.errorMessage = error.localizedDescription
                self.broadcasters = []
            case .success(let users):
                // Optional: sort by lastActiveAt desc
                self.broadcasters = users.sorted {
                    ($0.lastActiveAt ?? .distantPast) > ($1.lastActiveAt ?? .distantPast)
                }
            }
        }
    }

    func stopListening() {
        guard isListening else { return }
        isListening = false
        userService.stopListening()
    }
}

