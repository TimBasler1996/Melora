//
//  User.swift
//  SocialSound
//
//  Created by Tim Basler on 17.11.2025.
//


import Foundation

/// Lightweight user model used inside sessions and UI.
/// Separate from `AppUser` which represents the persisted user in Firestore.
struct User: Identifiable, Codable, Equatable {
    var id: String              // usually spotifyId
    var displayName: String
    var avatarURL: URL?
    var age: Int?
    var countryCode: String?
    
    init(
        id: String,
        displayName: String,
        avatarURL: URL? = nil,
        age: Int? = nil,
        countryCode: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.avatarURL = avatarURL
        self.age = age
        self.countryCode = countryCode
    }
}
