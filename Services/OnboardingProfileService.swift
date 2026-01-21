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

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    // MARK: - Basics model

    struct Basics {
        let firstName: String
        let lastName: String
        let city: String
        let birthday: Date
        let gender: String
    }

    // MARK: - Step 1: Save basics

    func saveBasics(_ basics: Basics, uid: String) async throws {
        let data: [String: Any] = [
            "firstName": basics.firstName,
            "lastName": basics.lastName,
            "city": basics.city,
            "birthday": Timestamp(date: basics.birthday),
            "gender": basics.gender,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await db.collection("users")
            .document(uid)
            .setData(data, merge: true)
    }

    // MARK: - Step 2: Photos

    func uploadPhotos(images: [UIImage], uid: String) async throws -> [String] {
        guard images.count >= 2 && images.count <= 5 else {
            throw NSError(domain: "Onboarding", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Between 2 and 5 photos are required."
            ])
        }

        var urls: [String] = []

        for (index, image) in images.enumerated() {
            let url = try await uploadPhoto(image: image, uid: uid, index: index)
            urls.append(url)
        }

        return urls
    }

    /// Upload a photo at a specific index
    /// - Note: Index 0 is the profile photo (shown on discovery cards and as avatar)
    ///         All photos are uploaded in their original quality
    func uploadPhoto(image: UIImage, uid: String, index: Int) async throws -> String {
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "Onboarding", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid image data."
            ])
        }

        let ref = storage.reference()
            .child("userPhotos")
            .child(uid)
            .child("photo_\(index).jpg")

        _ = try await ref.putDataAsync(data)
        let url = try await ref.downloadURL()
        return url.absoluteString
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
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw NSError(domain: "Onboarding", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Invalid image data."
            ])
        }

        let ref = storage.reference()
            .child("userPhotos")
            .child(uid)
            .child("hero_photo.jpg")

        _ = try await ref.putDataAsync(data)
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
