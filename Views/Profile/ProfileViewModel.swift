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
    @Published var countryCode: String = ""   // UI darf das weiterhin zeigen
    @Published var gender: String = ""        // UI darf das weiterhin zeigen
    
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
    
    /// Lädt ein Profil anhand "userId".
    /// In deinem aktuellen Setup ist das Firestore-Dokument die Firebase UID.
    func loadProfile(spotifyId userId: String, createFromSpotifyIfMissing: Bool = false) {
        isLoading = true
        errorMessage = nil
        saveSucceeded = false
        
        userService.getUser(uid: userId) { [weak self] result in
            guard let self else { return }
            self.isLoading = false
            
            switch result {
            case .failure(let error):
                self.errorMessage = "Failed to load profile: \(error.localizedDescription)"
                
            case .success(let maybeUser):
                guard let user = maybeUser else {
                    self.errorMessage = "No profile found."
                    return
                }
                
                self.appUser = user
                self.applyUserToFields(user)
            }
        }
    }
    
    /// Convenience: lädt den aktuell eingeloggten User (uid).
    func loadCurrentUser() {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "No Firebase user."
            return
        }
        loadProfile(spotifyId: uid)
    }
    
    private func applyUserToFields(_ user: AppUser) {
        displayName = user.displayName
        ageString = user.age.map(String.init) ?? ""
        hometown = user.hometown ?? ""
        
        // Falls dein aktueller AppUser diese Felder nicht hat,
        // bleiben sie in der UI leer, wir speichern sie trotzdem separat (siehe saveProfile()).
        // countryCode / gender bleiben wie sie sind (oder leer).
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
        
        // Update für die Felder, die dein aktueller AppUser sicher hat
        var data: [String: Any] = [
            "displayName": displayName,
            "updatedAt": Timestamp(date: Date()),
            "lastActiveAt": Timestamp(date: Date())
        ]
        
        if let ageInt { data["age"] = ageInt }
        if !hometown.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            data["hometown"] = hometown
        }
        
        // Optional UI-Felder (auch wenn AppUser sie nicht modelliert)
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
            
            // Re-load damit UI den neuesten Stand hat
            self.loadCurrentUser()
        }
    }
}

