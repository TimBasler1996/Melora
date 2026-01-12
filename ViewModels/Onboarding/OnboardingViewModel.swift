import Foundation
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

@MainActor
final class OnboardingViewModel: ObservableObject {

    @Published var stepIndex: Int = 1

    @Published var firstName: String = ""
    @Published var lastName: String = ""
    @Published var city: String = ""
    @Published var birthday: Date = Date()
    @Published var gender: String = ""

    @Published var profilePhotoData: Data?
    @Published var photo2Data: Data?
    @Published var photo3Data: Data?

    @Published var isConnectingSpotify: Bool = false
    @Published var isSpotifyConnected: Bool = false
    @Published var isSpotifyProfileLinked: Bool = false
    @Published var spotifyErrorMessage: String?
    @Published var finishErrorMessage: String?

    var progressText: String { "\(stepIndex)/3" }
    var progressValue: Double { Double(stepIndex) / 3.0 }

    var canContinueStep1: Bool {
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)

        guard trimmedFirst.count >= 2,
              trimmedLast.count >= 2,
              trimmedCity.count >= 2,
              !trimmedGender.isEmpty else {
            return false
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let selectedDay = calendar.startOfDay(for: birthday)
        guard selectedDay <= today else { return false }
        guard selectedDay >= Self.minimumBirthday else { return false }

        return true
    }

    private var hasAllPhotos: Bool {
        profilePhotoData != nil && photo2Data != nil && photo3Data != nil
    }

    /// Used by OnboardingFlowView for CTA enabling.
    var canContinueCurrentStep: Bool {
        switch stepIndex {
        case 1: return canContinueStep1
        case 2: return canContinueStep1 && hasAllPhotos
        case 3: return canContinueStep1 && hasAllPhotos && isSpotifyConnected
        default: return false
        }
    }

    func goNext() {
        if stepIndex == 1, !canContinueStep1 { return }

        guard stepIndex < 3 else {
            Task { await finishOnboarding() }
            return
        }

        stepIndex += 1
    }

    func goBack() {
        guard stepIndex > 1 else { return }
        stepIndex -= 1
    }

    func startSpotifyAuth() {
        spotifyErrorMessage = nil
        let auth = SpotifyAuthManager.shared
        auth.ensureAuthorized()

        if auth.isAuthorized {
            updateSpotifyConnection(true)
        }
    }

    func updateSpotifyConnection(_ isAuthorized: Bool) {
        isSpotifyConnected = isAuthorized

        guard isAuthorized else {
            isSpotifyProfileLinked = false
            return
        }
        Task { await syncSpotifyProfileIfNeeded() }
    }

    func syncSpotifyProfileIfNeeded() async {
        guard !isConnectingSpotify, !isSpotifyProfileLinked else { return }

        isConnectingSpotify = true
        spotifyErrorMessage = nil
        defer { isConnectingSpotify = false }

        do {
            let profile = try await SpotifyService.shared.fetchCurrentUserProfile()
            try await ensureUserFromSpotify(profile)
            isSpotifyProfileLinked = true
            spotifyErrorMessage = nil
        } catch {
            spotifyErrorMessage = error.localizedDescription
        }
    }

    private func ensureUserFromSpotify(_ profile: SpotifyUserProfile) async throws {
        try await withCheckedThrowingContinuation { continuation in
            UserApiService.shared.ensureCurrentUserExistsFromSpotify(
                spotifyId: profile.id,
                displayName: profile.displayName,
                countryCode: profile.countryCode,
                avatarURL: profile.imageURL?.absoluteString
            ) { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func finishOnboarding() async {
        finishErrorMessage = nil
        guard let uid = Auth.auth().currentUser?.uid else {
            finishErrorMessage = "No Firebase user."
            return
        }

        do {
            if isSpotifyConnected && !isSpotifyProfileLinked {
                await syncSpotifyProfileIfNeeded()
                if !isSpotifyProfileLinked {
                    finishErrorMessage = "Spotify connection not completed. Please try again."
                    return
                }
            }
            let photoURLs = try await uploadPhotos(uid: uid)
            try await saveBasics(uid: uid, photoURLs: photoURLs)
            try await markProfileCompleted(uid: uid)
        } catch {
            finishErrorMessage = error.localizedDescription
        }
    }

    private func uploadPhotos(uid: String) async throws -> [String] {
        let dataList = [profilePhotoData, photo2Data, photo3Data].compactMap { $0 }
        guard !dataList.isEmpty else { return [] }

        let storage = Storage.storage()
        var urls: [String] = []
        urls.reserveCapacity(min(dataList.count, 3))

        for data in dataList.prefix(3) {
            let name = UUID().uuidString + ".jpg"
            let path = "userPhotos/\(uid)/\(name)"
            let ref = storage.reference().child(path)

            _ = try await ref.putDataAsync(data, metadata: nil)
            let downloadURL = try await ref.downloadURL()
            urls.append(downloadURL.absoluteString)
        }

        return urls
    }

    private func saveBasics(uid: String, photoURLs: [String]) async throws {
        let db = Firestore.firestore()
        let trimmedFirst = firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLast = lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCity = city.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGender = gender.trimmingCharacters(in: .whitespacesAndNewlines)

        var data: [String: Any] = [
            "firstName": trimmedFirst,
            "lastName": trimmedLast,
            "city": trimmedCity,
            "gender": trimmedGender,
            "birthday": Timestamp(date: birthday),
            "updatedAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ]

        if !photoURLs.isEmpty {
            data["photoURLs"] = photoURLs
            data["avatarURL"] = photoURLs.first as Any
            data["avatarSource"] = "uploaded"
        }

        try await db.collection("users").document(uid).setData(data, merge: true)
    }

    private func markProfileCompleted(uid: String) async throws {
        let db = Firestore.firestore()
        try await db.collection("users").document(uid).setData([
            "profileCompleted": true,
            "updatedAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ], merge: true)
    }

    private static var minimumBirthday: Date {
        let components = DateComponents(year: 1900, month: 1, day: 1)
        return Calendar.current.date(from: components) ?? Date.distantPast
    }
}
