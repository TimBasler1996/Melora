//
//  ProfileViewModel.swift
//  SocialSound
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

/// ViewModel for the Profile screen.
///
/// Verantwortlich für:
/// - Laden des AppUser aus Firestore (users/{uid})
/// - Falls nicht vorhanden: erzeugen via Spotify (/me) und dann reload
/// - Bearbeiten und Speichern von Profilfeldern
@MainActor
final class ProfileViewModel: ObservableObject {

    // MARK: - Published State (for UI)

    @Published var isLoading: Bool = false
    @Published var isSaving: Bool = false
    @Published var saveSucceeded: Bool = false
    @Published var errorMessage: String?

    @Published var appUser: AppUser?

    // Felder, die die UI bindet
    @Published var displayName: String = ""
    @Published var ageString: String = ""
    @Published var hometown: String = ""
    @Published var countryCode: String = ""
    @Published var gender: String = ""

    private let userService = UserApiService.shared
    private let db = Firestore.firestore()

    // MARK: - Derived

    var canSave: Bool {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !isSaving
    }

    private var ageInt: Int? {
        let trimmed = ageString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Int(trimmed)
    }

    // MARK: - Loading

    /// Lädt ein Profil anhand `uid` (Firestore doc id = Firebase UID).
    /// Parametername ist aus historischen Gründen "spotifyId", aber es ist UID gemeint.
    func loadProfile(spotifyId uid: String, createFromSpotifyIfMissing: Bool = false) {
        isLoading = true
        errorMessage = nil
        saveSucceeded = false

        userService.getUser(uid: uid) { [weak self] result in
            guard let self else { return }
            self.isLoading = false

            switch result {
            case .success(let user):
                self.appUser = user
                self.applyUserToFields(user)

            case .failure(let error):
                // Wenn gewünscht: missing -> neu erstellen aus Spotify, dann anzeigen
                if createFromSpotifyIfMissing {
                    Task { [weak self] in
                        guard let self else { return }
                        await self.createFromSpotifyIfNeededAndLoad(uid: uid)
                    }
                } else {
                    self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                }
            }
        }
    }

    /// Convenience: lädt den aktuell eingeloggten User (uid).
    func loadCurrentUser(createFromSpotifyIfMissing: Bool = false) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            return
        }
        loadProfile(spotifyId: uid, createFromSpotifyIfMissing: createFromSpotifyIfMissing)
    }

    private func applyUserToFields(_ user: AppUser) {
        displayName = user.displayName
        ageString = user.age.map(String.init) ?? ""
        hometown = user.hometown ?? ""
        countryCode = user.countryCode ?? ""
        gender = user.gender ?? ""
    }

    @MainActor
    private func createFromSpotifyIfNeededAndLoad(uid: String) async {
        do {
            // 1) Spotify /me holen
            let spotify = try await SpotifyService.shared.fetchCurrentUserProfile()

            // 2) Firestore doc users/{uid} sicherstellen
            userService.ensureCurrentUserExistsFromSpotify(
                spotifyId: spotify.id,
                displayName: spotify.displayName,
                countryCode: spotify.countryCode,
                avatarURL: spotify.imageURL?.absoluteString
            ) { [weak self] res in
                guard let self else { return }
                switch res {
                case .success(let user):
                    self.appUser = user
                    self.applyUserToFields(user)
                case .failure(let e):
                    self.errorMessage = "Failed to create profile: \(e.localizedDescription)"
                }
            }
        } catch {
            self.errorMessage = "Spotify profile fetch failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Saving

    /// Speichert die aktuellen Form-Felder zurück nach Firestore users/{uid}.
    func saveProfile() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            return
        }

        isSaving = true
        errorMessage = nil
        saveSucceeded = false

        var data: [String: Any] = [
            "displayName": displayName,
            "updatedAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ]

        if let ageInt { data["age"] = ageInt }

        if !hometown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["hometown"] = hometown
        } else {
            // optional: löschen, wenn leer
            // data["hometown"] = FieldValue.delete()
        }

        if !countryCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["countryCode"] = countryCode
        }

        if !gender.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["gender"] = gender
        }

        db.collection("users").document(uid).setData(data, merge: true) { [weak self] error in
            guard let self else { return }
            self.isSaving = false

            if let error {
                self.errorMessage = "Save failed: \(error.localizedDescription)"
                return
            }

            self.saveSucceeded = true

            // Reload: wenn doc nicht existierte, jetzt existiert er garantiert
            self.loadCurrentUser(createFromSpotifyIfMissing: true)
        }
    }
}

