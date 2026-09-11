//
//  OnboardingProfileService 2.swift
//  SocialSound
//
//  Created by Tim Basler on 13.01.2026.
//


import Foundation
import FirebaseFirestore
import FirebaseAuth
import FirebaseStorage
import UIKit

@MainActor
final class OnboardingProfileService {

    // Lazy: keeps previews that build this service from hitting Firebase.
    private lazy var db = Firestore.firestore()
    private lazy var storage = Storage.storage()

    // MARK: - Basics model

    struct Basics {
        let firstName: String
        let lastName: String
        let city: String
        /// `nil` leaves the stored birthday untouched.
        let birthday: Date?
        let gender: String
        let lookingFor: String?
    }

    // MARK: - Step 1: Save basics

    func saveBasics(_ basics: Basics, uid: String) async throws {
        let displayName = [basics.firstName, basics.lastName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")

        var data: [String: Any] = [
            "firstName": basics.firstName,
            "lastName": basics.lastName,
            "city": basics.city,
            "gender": basics.gender,
            "updatedAt": FieldValue.serverTimestamp()
        ]
        if !displayName.isEmpty {
            // Keep the denormalised name (likes, chats, notifications) and the
            // lowercase prefix-search fields in sync with the edited name.
            data["displayName"] = displayName
            data["displayNameLower"] = displayName.lowercased()
            data["firstNameLower"] = basics.firstName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            data["lastNameLower"] = basics.lastName
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
        }
        if let birthday = basics.birthday {
            data["birthday"] = Timestamp(date: birthday)
        }
        if let lookingFor = basics.lookingFor {
            data["lookingFor"] = lookingFor
        }

        try await db.collection("users")
            .document(uid)
            .setData(data, merge: true)
    }

    // MARK: - Step 2: Photos

    /// Upload a photo at a specific index
    /// - Note: Index 0 is the profile photo (shown on discovery cards and as avatar).
    ///         Photos are downscaled to `UIImage.profilePhotoMaxDimension` before upload.
    func uploadPhoto(image: UIImage, uid: String, index: Int) async throws -> String {
        // Never ship raw camera-roll pixels: cap the longest edge before encoding.
        guard let data = image.downscaled().jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "Onboarding", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid image data."
            ])
        }

        let ref = storage.reference()
            .child("userPhotos")
            .child(uid)
            .child("photo_\(index).jpg")

        _ = try await ref.putDataAsync(data, metadata: Self.jpegMetadata())
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    /// Storage rules only accept `image/*` uploads, so always declare the type.
    private static func jpegMetadata() -> StorageMetadata {
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        return metadata
    }

    func savePhotos(photoURLs: [String], uid: String) async throws {
        try await db.collection("users")
            .document(uid)
            .setData([
                "photoURLs": photoURLs,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    /// Upload a hero photo (large banner image for profile)
    func uploadHeroPhoto(image: UIImage, uid: String) async throws -> String {
        // 1600 px covers a full-width hero at 3x; anything more only slows the feed.
        guard let data = image.downscaled().jpegData(compressionQuality: 0.8) else {
            throw NSError(domain: "Onboarding", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid image data."
            ])
        }

        let ref = storage.reference()
            .child("userPhotos")
            .child(uid)
            .child("hero_photo.jpg")

        _ = try await ref.putDataAsync(data, metadata: Self.jpegMetadata())
        let url = try await ref.downloadURL()
        return url.absoluteString
    }

    func saveHeroPhotoURL(_ heroURL: String, uid: String) async throws {
        try await db.collection("users")
            .document(uid)
            .setData([
                "heroPhotoURL": heroURL,
                "updatedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }

    // MARK: - Step 3: Spotify

    func saveSpotify(
        spotifyId: String,
        countryCode: String?,
        spotifyAvatarURL: String?,
        uid: String
    ) async throws {
        var data: [String: Any] = [
            "spotifyId": spotifyId,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let countryCode {
            data["spotifyCountry"] = countryCode
        }

        if let spotifyAvatarURL {
            data["spotifyAvatarURL"] = spotifyAvatarURL
        }

        try await db.collection("users")
            .document(uid)
            .setData(data, merge: true)
    }

    // MARK: - Finish onboarding

    func markCompleted(uid: String) async throws {
        try await db.collection("users")
            .document(uid)
            .setData([
                "profileCompleted": true,
                "completedAt": FieldValue.serverTimestamp()
            ], merge: true)
    }
}
