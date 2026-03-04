import Foundation
import FirebaseFirestore

/// 🔧 One-time script to fix existing likes that have "Unknown" or missing user data
/// Run this once in your app to update all existing likes with correct user information
///
/// Usage:
/// ```swift
/// Task {
///     await FixLikesUserDataScript.shared.fixAllLikes()
/// }
/// ```
actor FixLikesUserDataScript {
    
    static let shared = FixLikesUserDataScript()
    
    private let db = Firestore.firestore()
    
    /// Fixes all likes in the system by updating fromUserDisplayName and fromUserAvatarURL
    /// from the actual user documents in Firestore
    func fixAllLikes() async {
        print("🔧 [Fix] Starting to fix all likes with missing user data...")
        
        do {
            // Get all users
            let usersSnapshot = try await db.collection("users").getDocuments()
            let userCount = usersSnapshot.documents.count
            print("📊 [Fix] Found \(userCount) users in system")
            
            var fixedCount = 0
            var errorCount = 0
            
            // For each user, check their likesReceived and likesGiven
            for userDoc in usersSnapshot.documents {
                let userId = userDoc.documentID
                
                // Fix likesReceived
                let receivedCount = await fixLikesInCollection(
                    userId: userId,
                    collection: "likesReceived"
                )
                fixedCount += receivedCount.fixed
                errorCount += receivedCount.errors
                
                // Fix likesGiven
                let givenCount = await fixLikesInCollection(
                    userId: userId,
                    collection: "likesGiven"
                )
                fixedCount += givenCount.fixed
                errorCount += givenCount.errors
            }
            
            print("✅ [Fix] Complete! Fixed \(fixedCount) likes, \(errorCount) errors")
            
        } catch {
            print("❌ [Fix] Failed to fetch users: \(error.localizedDescription)")
        }
    }
    
    /// Fixes likes in a specific subcollection for a user
    private func fixLikesInCollection(userId: String, collection: String) async -> (fixed: Int, errors: Int) {
        var fixed = 0
        var errors = 0
        
        do {
            let likesSnapshot = try await db.collection("users")
                .document(userId)
                .collection(collection)
                .getDocuments()
            
            for likeDoc in likesSnapshot.documents {
                let data = likeDoc.data()
                let fromUserId = data["fromUserId"] as? String ?? ""
                let currentDisplayName = data["fromUserDisplayName"] as? String
                let currentAvatarURL = data["fromUserAvatarURL"] as? String
                
                // Check if this like needs fixing
                let needsFix = currentDisplayName == nil || 
                              currentDisplayName == "Unknown" || 
                              currentDisplayName?.isEmpty == true ||
                              currentAvatarURL == nil
                
                guard needsFix else { continue }
                
                // Fetch the actual user data
                do {
                    let userDoc = try await db.collection("users").document(fromUserId).getDocument()
                    
                    guard let userData = userDoc.data() else {
                        print("⚠️ [Fix] User \(fromUserId) not found in Firestore")
                        errors += 1
                        continue
                    }
                    
                    let realDisplayName = userData["displayName"] as? String
                    let realAvatarURL = userData["avatarURL"] as? String
                    
                    // Only update if we have better data
                    if realDisplayName != "Unknown" && realDisplayName?.isEmpty == false {
                        var updatePayload: [String: Any] = [:]
                        
                        if realDisplayName != currentDisplayName {
                            updatePayload["fromUserDisplayName"] = realDisplayName ?? "Unknown"
                        }
                        
                        if realAvatarURL != currentAvatarURL {
                            updatePayload["fromUserAvatarURL"] = realAvatarURL as Any
                        }
                        
                        if !updatePayload.isEmpty {
                            try await likeDoc.reference.updateData(updatePayload)
                            print("✅ [Fix] Updated like \(likeDoc.documentID): \(realDisplayName ?? "Unknown")")
                            fixed += 1
                        }
                    } else {
                        print("⚠️ [Fix] User \(fromUserId) still has incomplete profile (displayName=\(realDisplayName ?? "nil"))")
                        errors += 1
                    }
                    
                } catch {
                    print("❌ [Fix] Error updating like \(likeDoc.documentID): \(error.localizedDescription)")
                    errors += 1
                }
            }
            
        } catch {
            print("❌ [Fix] Failed to fetch likes for user \(userId)/\(collection): \(error.localizedDescription)")
            errors += 1
        }
        
        return (fixed, errors)
    }
    
    /// Fixes likes for a specific user only (useful for testing)
    func fixLikesForUser(userId: String) async {
        print("🔧 [Fix] Fixing likes for user \(userId)...")
        
        let receivedResult = await fixLikesInCollection(userId: userId, collection: "likesReceived")
        let givenResult = await fixLikesInCollection(userId: userId, collection: "likesGiven")
        
        let totalFixed = receivedResult.fixed + givenResult.fixed
        let totalErrors = receivedResult.errors + givenResult.errors
        
        print("✅ [Fix] User \(userId): Fixed \(totalFixed) likes, \(totalErrors) errors")
    }
}

// MARK: - Usage Example

/*
 To use this script, add this code somewhere in your app (e.g., in a debug menu or button):
 
 Button("Fix All Likes") {
     Task {
         await FixLikesUserDataScript.shared.fixAllLikes()
     }
 }
 
 Or to fix likes for a specific user:
 
 Button("Fix My Likes") {
     Task {
         if let userId = currentUserStore.user?.uid {
             await FixLikesUserDataScript.shared.fixLikesForUser(userId: userId)
         }
     }
 }
 */
