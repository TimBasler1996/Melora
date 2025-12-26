//
//  PhotoUploadError.swift
//  SocialSound
//
//  Created by Tim Basler on 25.12.2025.
//


import Foundation
import FirebaseAuth
import FirebaseStorage
import UIKit

enum PhotoUploadError: Error {
    case noFirebaseUser
    case jpegConversionFailed
    case downloadURLMissing
}

final class PhotoUploader {
    
    static let shared = PhotoUploader()
    private let storage = Storage.storage()
    
    private init() {}
    
    /// Uploads an image to: userPhotos/{uid}/{uuid}.jpg and returns the download URL string.
    func uploadProfilePhoto(image: UIImage) async throws -> String {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw PhotoUploadError.noFirebaseUser
        }
        
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw PhotoUploadError.jpegConversionFailed
        }
        
        let fileName = UUID().uuidString + ".jpg"
        let ref = storage.reference()
            .child("userPhotos")
            .child(uid)
            .child(fileName)
        
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await ref.putDataAsync(data, metadata: metadata)
        
        let url = try await ref.downloadURL()
        return url.absoluteString
    }
}
